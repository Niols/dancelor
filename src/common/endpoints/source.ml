open Nes
open Madge
open Model_new
open Search_new

type (_, _, _) t =
  | Get_row : (Source_id.t -> 'w, 'w, Source_row.t) t
  | Get_view : (Source_id.t -> 'w, 'w, Source_view.t) t
  | Get_form : (Source_id.t -> 'w, 'w, Source_form.t) t
  | Search : (Slice.t -> Source_query.t -> 'w, 'w, Source_row.t Search_result.t) t
  | Create : (Source_form.t -> 'w, 'w, Source_id.t) t
  | Update : (Source_id.t -> Source_form.t -> 'w, 'w, unit) t
  | Delete : (Source_id.t -> 'w, 'w, unit) t
  | Cover : (Source_id.t -> 'w, 'w, Void.t) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Source_query) @@ get (module Make_search_result(Source_row))
    | Get_row -> variable (module Source_id) @@ literal "row" @@ get (module Source_row)
    | Get_view -> variable (module Source_id) @@ literal "view" @@ get (module Source_view)
    | Get_form -> variable (module Source_id) @@ literal "form" @@ get (module Source_form)
    | Create -> body "source" (module Source_form) @@ post (module Source_id)
    | Update -> variable (module Source_id) @@ body "source" (module Source_form) @@ put (module JUnit)
    | Delete -> variable (module Source_id) @@ delete (module JUnit)
    | Cover -> variable (module Source_id) @@ literal "cover.webp" @@ void ()
