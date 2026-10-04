open Nes
open Madge
open Model
open Search

type (_, _, _) t =
  | Get_row : (Dance_id.t -> 'w, 'w, Dance_row.t) t
  | Get_view : (Dance_id.t -> 'w, 'w, Dance_view.t) t
  | Get_form : (Dance_id.t -> 'w, 'w, Dance_form.t) t
  | Search : (Slice.t -> Dance_query.t -> 'w, 'w, Dance_row.t Search_result.t) t
  | Create : (Dance_form.t -> 'w, 'w, Dance_id.t) t
  | Update : (Dance_id.t -> Dance_form.t -> 'w, 'w, unit) t
  | Delete : (Dance_id.t -> 'w, 'w, unit) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Get_row -> variable (module Dance_id) @@ literal "row" @@ get (module Dance_row)
    | Get_view -> variable (module Dance_id) @@ literal "view" @@ get (module Dance_view)
    | Get_form -> variable (module Dance_id) @@ literal "form" @@ get (module Dance_form)
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Dance_query) @@ get (module Make_search_result(Dance_row))
    | Create -> body "dance" (module Dance_form) @@ post (module Dance_id)
    | Update -> variable (module Dance_id) @@ body "dance" (module Dance_form) @@ put (module JUnit)
    | Delete -> variable (module Dance_id) @@ delete (module JUnit)
