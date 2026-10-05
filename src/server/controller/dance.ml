open Nes_unix
open Dancelor_common

include Shared.Make_public(struct
  type tag = Dance_tag.t
  type id = Dance_id.t
  type row = Dance_row.t
  type view = Dance_view.t
  type form = Dance_form.t
  type query = Dance_query.t
  include Database.Dance
end)

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Dance.t -> a = fun env endpoint ->
  match endpoint with
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
