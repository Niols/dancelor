open Nes
open Dancelor_common
open Model_new
open Search_new

include Shared.Make_private_full(struct
  type entry = Model_builder.Core.Set.t
  type id = Set_id.t
  type row = Set_row.t
  type view = Set_view.t
  type form = Set_form.t
  type query = Set_query.t
  include Database.Set
end)

let add_version_to_contents env id version_id =
  (* FIXME: make all the database endpoints take the database such that
     endpoints like this one can share a transaction *)
  (* A bit stupid to have to get a whole version row to put back into the form
     when updating the database doesn't need the row at all. On the other hand,
     updating the database doesn't happen this often. *)
  let%lwt form = get_form env id in
  let%lwt version_row = Version.get_row env version_id in
  update env id {form with contents = form.contents @ [(version_row, Model_builder.Core.Version_parameters.none)]}

(* Legacy *)

let get env id =
  match%lwt Database.Set.get id with
  | None -> Permission.reject_can_get ()
  | Some set ->
    Permission.assert_can_get_private env set;%lwt
    lwt set

let build_pdf env id set_params rendering_params =
  get env id >>= fun set ->
  let%lwt set = Model_to_renderer.set_to_renderer_set' (Entry.id set) set_params in
  let set_pdf_arg = Model_to_renderer.renderer_set_to_renderer_set_pdf_arg set rendering_params in
  uncurry Job.register_job_and_file <$> Renderer.make_set_pdf set_pdf_arg

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Set.t -> a = fun env endpoint ->
  match endpoint with
  | Get -> get env
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Get_rows -> get_rows env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Add_version_to_contents -> add_version_to_contents env
  | Delete -> delete env
  | Build_pdf -> build_pdf env
