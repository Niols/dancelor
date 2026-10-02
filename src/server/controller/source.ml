open Nes
open Dancelor_common
open Model_new
open Search_new

include Shared.Make_public_full(struct
  type entry = Model_builder.Core.Source.t
  type id = Source_id.t
  type row = Source_row.t
  type view = Source_view.t
  type form = Source_form.t
  type query = Source_query.t
  include Database.Source
end)

(* Legacy *)
let get _env id =
  match%lwt Database.Source.get id with
  | None -> Permission.reject_can_get ()
  | Some source -> lwt source

let get_cover _env id =
  Database.Source.with_cover id @@ fun fname ->
  let fname = Option.value fname ~default: (Filename.concat (Config.get ()).share "no-cover.webp") in
  Madge_server.respond_file ~fname

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Source.t -> a = fun env endpoint ->
  match endpoint with
  | Get -> get env
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
  | Cover -> get_cover env
