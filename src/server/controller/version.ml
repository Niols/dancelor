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

(** Additionnally to the low-level permission system, version content is
    protected by copyright, so we check whether the composer or the publisher of
    the tune agree on this publication *)
let with_copyright_check env (version : Version_view.t) f =
  let%lwt connected = Permission.is_connected env in
  let%lwt composer_agrees =
    let%lwt composers = Lwt_list.map_p (Option.get <%> Database.Person.get_view % Person_name_with_details.id) version.tune.composers in
    let%lwt arrangers = Lwt_list.map_p (Option.get <%> Database.Person.get_view % Person_name.id) version.arrangers in
    lwt (
      composers <> [] (* there must be at least one composer to agree *)
      && List.for_all Person_view.composed_tunes_are_public composers
      && List.for_all Person_view.composed_tunes_are_public arrangers
    )
  in
  let%lwt publisher_agrees =
    let source_editors_agree (source : Source_view.t) =
      let%lwt editors = Lwt_list.map_s (Option.get <%> Database.Person.get_view % Person_name.id) source.editors in
      lwt @@ List.exists Person_view.published_tunes_are_public editors
    in
    Lwt_list.filter_s source_editors_agree =<< (Lwt_list.map_p (Option.get <%> Database.Source.get_view % Version_view.source_id) version.sources)
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
      | source :: _ -> Some (Endpoints.Version.Publisher_agrees (Source_view.to_name source))
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

let can_get_and_copyright_ok env (version : Version_view.t) =
  ((<>) Endpoints.Version.Protected) <$> with_copyright_check env version (const lwt_unit)

let get_view_for_tune env id =
  let views = Database.Version.get_views_for_tune id in
  let stream = (Lwt_stream.filter_s (can_get_and_copyright_ok env) % Lwt_stream.of_list) <$> views in
  let stream = Lwt_stream.flip_lwt stream in
  (* FIXME: some logic to choose a “good” version? *)
  match%lwt Lwt_stream.get stream with
  | Some version -> lwt @@ Endpoints.Version.Version_view_fallback.Found version
  | None -> (fun t -> Endpoints.Version.Version_view_fallback.Fallback t) <$> Tune.get_view env id

let content env id =
  Log.debug (fun m -> m "content %a" Entry.Id.pp' id);
  get_view env id >>= fun version ->
  with_copyright_check env version @@ fun () ->
  let%lwt content = Option.get <$> Database.Version.get_content version.id in
  lwt @@ Option.get @@ Model_builder.Core.Version.Content.lilypond ~kind: version.tune.kind ~key: version.key content

let build_pdf env id version_params rendering_params =
  Log.debug (fun m -> m "build_pdf %a" Entry.Id.pp' id);
  get_view env id >>= fun version ->
  with_copyright_check env version @@ fun () ->
  (* never show the headers for a simple version *)
  let rendering_params = Rendering_parameters.update ~show_headers: (const (some false)) rendering_params in
  let set_params = Model_builder.Core.Set_parameters.make ?display_name: (Model_builder.Core.Version_parameters.display_name version_params) () in
  let version_params = Model_builder.Core.Version_parameters.set_display_name (NEString.of_string_exn " ") version_params in
  let%lwt version_form = Option.get <$> Database.Version.get_form version.id in
  let set = Model_to_renderer.versions_to_renderer_set (NEList.singleton (version_form, version_params)) set_params in
  let set_pdf_arg = Model_to_renderer.renderer_set_to_renderer_set_pdf_arg set rendering_params in
  uncurry Job.register_job_and_file <$> Renderer.make_set_pdf set_pdf_arg

(** For use in {!Routine}. *)
let render_snippets ?version_params version =
  let tune = Model_to_renderer.version_to_renderer_tune ?version_params version in
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
  let tune = Model_to_renderer.version_to_renderer_tune ?version_params version in
  register_snippets_job_gen tune

let build_snippets env id version_params _rendering_params =
  Log.debug (fun m -> m "build_snippets %a" Entry.Id.pp' id);
  get_view env id >>= fun version ->
  with_copyright_check env version @@ fun () ->
  let%lwt version_form = Option.get <$> Database.Version.get_form version.id in
  register_snippets_job ~version_params version_form

let build_snippets' env version version_params _rendering_params =
  Log.debug (fun m -> m "build_snippets'");
  Shared.assert_can_create () env @@ fun _actor ->
  register_snippets_job ~version_params version

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Version.t -> a = fun env endpoint ->
  match endpoint with
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
