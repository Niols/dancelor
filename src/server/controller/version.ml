open NesUnix
open Dancelor_common
open Model_new
open Search_new

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.version": Logs.LOG)

include Shared.Make_public_full(struct
  type entry = Model_builder.Core.Version.t
  type id = Version_id.t
  type row = Version_row.t
  type view = Version_view.t
  type form = Version_form.t
  type query = Version_query.t
  include Database.Version
end)

(* Legacy *)

let get env id =
  match%lwt Database.Version.get id with
  | None -> Permission.reject_can_get ()
  | Some version ->
    Permission.assert_can_get_public env version;%lwt
    lwt version

(** Additionnally to the low-level permission system, version content is
    protected by copyright, so we check whether the composer or the publisher of
    the tune agree on this publication *)
let with_copyright_check env version f =
  let%lwt tune = Model.Version.tune' version in
  let%lwt connected = Permission.is_connected env in
  let%lwt composer_agrees =
    let%lwt composers = Lwt_list.map_p (Option.get <%> Model.Person.get % Model.Tune.composer_composer) (Model.Tune.composers' tune) in
    let%lwt arrangers = Lwt_list.map_p (Option.get <%> Model.Person.get) (Model.Version.arrangers' version) in
    lwt (
      composers <> [] (* there must be at least one composer to agree *)
      && List.for_all Model.Person.composed_tunes_are_public' composers
      && List.for_all Model.Person.composed_tunes_are_public' arrangers
    )
  in
  let%lwt publisher_agrees =
    let source_editors_agree source =
      let%lwt editors = Lwt_list.map_s (Option.get <%> Model.Person.get) @@ Model.Source.editors' source in
      lwt @@ List.exists Model.Person.published_tunes_are_public' editors
    in
    Lwt_list.filter_s source_editors_agree =<< (Lwt_list.map_p (Option.get <%> Model.Source.get % Model.Version.source_source) @@ Model.Version.sources' version)
  in
  (* let's see if we have a reason to agree to showing this version's content;
     if the composer (and arranger) agrees, that's it; otherwise, if there is a
     source and the publisher agrees, that's is; and finally, if we are
     connected, we get a pass (for now) *)
  let reason =
    if composer_agrees then
      Some Endpoints.Version.Composer_agrees
    else
      match publisher_agrees with
      | source :: _ -> Some (Endpoints.Version.Publisher_agrees source)
      | [] ->
        if connected then
          Some Endpoints.Version.Connected
        else None
  in
  match reason with
  | None -> lwt Endpoints.Version.Protected
  | Some reason ->
    let%lwt payload = f () in
    lwt (Endpoints.Version.Granted {payload; reason})

let can_get_and_copyright_ok env version =
  Lwt.l2
    (&&)
    (Permission.can_get_public env version)
    (((<>) Endpoints.Version.Protected) <$> with_copyright_check env version (const lwt_unit))

let get_view_for_tune env id =
  let all = Database.Version.get_all_for_tune id in
  let stream = (Lwt_stream.filter_s (can_get_and_copyright_ok env) % Lwt_stream.of_list) <$> all in
  let stream = Lwt_stream.flip_lwt stream in
  (* FIXME: some logic to choose a “good” version? *)
  match%lwt Lwt_stream.get stream with
  | Some version -> (fun v -> Endpoints.Version.Version_view_fallback.Found v) <$> get_view env (Entry.id version)
  | None -> (fun t -> Endpoints.Version.Version_view_fallback.Fallback t) <$> Tune.get_view env id

let content env id =
  Log.debug (fun m -> m "content %a" Entry.Id.pp' id);
  get env id >>= fun version ->
  with_copyright_check env version @@ fun () ->
  lwt @@ Model.Version.content' version

let build_pdf env id version_params rendering_params =
  Log.debug (fun m -> m "build_pdf %a" Entry.Id.pp' id);
  get env id >>= fun version ->
  with_copyright_check env version @@ fun () ->
  (* never show the headers for a simple version *)
  let rendering_params = Rendering_parameters.update ~show_headers: (const (some false)) rendering_params in
  let set_params = Model.Set_parameters.make ?display_name: (Model.Version_parameters.display_name version_params) () in
  let version_params = Model.Version_parameters.set_display_name (NEString.of_string_exn " ") version_params in
  let%lwt set = Model_to_renderer.versions_to_renderer_set' (NEList.singleton (Entry.id version, version_params)) set_params in
  let set_pdf_arg = Model_to_renderer.renderer_set_to_renderer_set_pdf_arg set rendering_params in
  uncurry Job.register_job_and_file <$> Renderer.make_set_pdf set_pdf_arg

(** For use in {!Routine}. *)
let render_snippets ?version_params version =
  let%lwt tune = Model_to_renderer.version_to_renderer_tune ?version_params version in
  Renderer.make_tune_snippets tune

let register_snippets_job_gen renderer_tune =
  let%lwt svg_job = Renderer.make_tune_svg renderer_tune in
  let%lwt ogg_job = Renderer.make_tune_ogg renderer_tune in
  lwt @@
    match (uncurry Job.register_job_and_file svg_job, uncurry Job.register_job_and_file ogg_job) with
    | Already_succeeded svg_job_id, Already_succeeded ogg_job_id -> Endpoints.Job.Already_succeeded {Endpoints.Version.Snippet_ids.svg_job_id; ogg_job_id}
    | Registered svg_job_id, Already_succeeded ogg_job_id -> Registered {svg_job_id; ogg_job_id}
    | Already_succeeded svg_job_id, Registered ogg_job_id -> Registered {svg_job_id; ogg_job_id}
    | Registered svg_job_id, Registered ogg_job_id -> Registered {svg_job_id; ogg_job_id}

let register_snippets_job ?version_params version =
  let%lwt tune = Model_to_renderer.version_to_renderer_tune ?version_params version in
  register_snippets_job_gen tune

let register_snippets_job_new ?version_params version =
  let tune = Model_to_renderer.version_to_renderer_tune_new ?version_params version in
  register_snippets_job_gen tune

let build_snippets env id version_params _rendering_params =
  Log.debug (fun m -> m "build_snippets %a" Entry.Id.pp' id);
  get env id >>= fun version ->
  with_copyright_check env version @@ fun () ->
  register_snippets_job ~version_params (Entry.value version)

let build_snippets' env version version_params _rendering_params =
  Log.debug (fun m -> m "build_snippets'");
  Permission.assert_can_create_public env;%lwt
  register_snippets_job ~version_params version

let build_snippets'_new env version version_params _rendering_params =
  Log.debug (fun m -> m "build_snippets'_new");
  Permission.assert_can_create_public env;%lwt
  register_snippets_job_new ~version_params version

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Version.t -> a = fun env endpoint ->
  match endpoint with
  | Get -> get env
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Get_view_for_tune -> get_view_for_tune env
  | Content -> content env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
  | Build_pdf -> build_pdf env
  | Build_snippets -> build_snippets env
  | Build_snippets' -> build_snippets' env
  | Build_snippets'_new -> build_snippets'_new env
