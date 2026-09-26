open Nes
open Madge
open Model_new
open Search_new
open Model_builder.Core

type (_, _, _) t =
  | For_user : (User_id.t -> 'w, 'w, Person_row.t option) t
  | Get : (Person_id.t -> 'w, 'w, Person.entry) t (* FIXME: remove *)
  | Get_row : (Person_id.t -> 'w, 'w, Person_row.t) t
  | Get_view : (Person_id.t -> 'w, 'w, Person_view.t) t
  | Get_form : (Person_id.t -> 'w, 'w, Person_form.t) t
  | Search : (Slice.t -> Person_query.t -> 'w, 'w, Person_row.t Search_result.t) t
  | Create : (Person_form.t -> 'w, 'w, Person_id.t) t
  | Update : (Person_id.t -> Person_form.t -> 'w, 'w, unit) t
  | Delete : (Person_id.t -> 'w, 'w, unit) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | For_user -> literal "for-user" @@ variable (module User_id) @@ literal "row" @@ get (module JOption(Person_row))
    | Create -> body "person" (module Person_form) @@ post (module Person_id)
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Person_query) @@ get (module Make_search_result(Person_row))
    | Get -> variable (module Person_id) @@ get (module Entry.JPublic(Person))
    | Get_row -> variable (module Person_id) @@ literal "row" @@ get (module Person_row)
    | Get_view -> variable (module Person_id) @@ literal "view" @@ get (module Person_view)
    | Get_form -> variable (module Person_id) @@ literal "form" @@ get (module Person_form)
    | Update -> variable (module Person_id) @@ body "person" (module Person_form) @@ put (module JUnit)
    | Delete -> variable (module Person_id) @@ delete (module JUnit)
