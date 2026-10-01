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

let for_user env id =
  match%lwt Database.Person.get_row_for_user id with
  | None -> lwt_none
  | Some person ->
    Permission.assert_can_get_public_new env person;%lwt
    lwt_some person

(* Legacy *)
let get env id =
  match%lwt Database.Person.get id with
  | None -> Permission.reject_can_get ()
  | Some person ->
    Permission.assert_can_get_public env person;%lwt
    lwt person

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Person.t -> a = fun env endpoint ->
  match endpoint with
  | Get -> get env
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Search -> search env
  | For_user -> for_user env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
