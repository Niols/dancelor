open Nes
open Madge
open Model
open Search

type (_, _, _) t =
  | Get_row : (Group_id.t -> 'w, 'w, Group_row.t) t
  | Get_view : (Group_id.t -> 'w, 'w, Group_view.t) t
  | Get_form : (Group_id.t -> 'w, 'w, Group_form.t) t
  | Create : (Group_form.t -> 'w, 'w, Group_id.t) t
  | Update : (Group_id.t -> Group_form.t -> 'w, 'w, unit) t
  | Search : (Slice.t -> Group_query.t -> 'w, 'w, Group_row.t Search_result.t) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Get_row -> variable (module Group_id) @@ literal "row" @@ get (module Group_row)
    | Get_view -> variable (module Group_id) @@ literal "view" @@ get (module Group_view)
    | Get_form -> variable (module Group_id) @@ literal "form" @@ get (module Group_form)
    | Create -> literal "create" @@ body "group" (module Group_form) @@ post (module Group_id)
    | Update -> variable (module Group_id) @@ body "group" (module Group_form) @@ put (module JUnit)
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Group_query) @@ get (module Make_search_result(Group_row))
