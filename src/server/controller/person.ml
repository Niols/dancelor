open Nes
open Dancelor_common
open Model_new
open Search_new

include Shared.Make_public_full(struct
  type entry = Model_builder.Core.Person.t
  type id = Person_id.t
  type row = Person_row.t
  type view = Person_view.t
  type form = Person_form.t
  type query = Person_query.t
  include Database.Person
end)

(* Legacy *)
let get _env id =
  match%lwt Database.Person.get id with
  | None -> Permission.reject_can_get ()
  | Some person -> lwt person

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Person.t -> a = fun env endpoint ->
  match endpoint with
  | Get -> get env
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
