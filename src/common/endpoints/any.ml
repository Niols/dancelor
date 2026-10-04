open Nes
open Madge
open Model_new
open Search

type (_, _, _) t =
  | Get_type : (unit Entry.Id.t -> 'w, 'w, Model_builder.Core.Any.Type.t) t
  | Get_rows : (Any_id.t list -> 'w, 'w, Any_row.t list) t
  | Newest : (int -> 'w, 'w, Any_row.t list) t
  | Search : (Slice.t -> Any_query.t -> 'w, 'w, Any_row.t Search_result.t) t
  | Search_context_5_10 : (Any_query.t -> Any_id.t -> 'w, 'w, Any_id.t Search_context_result.t) t
  | Get_permissions : (unit Entry.Id.t -> 'w, 'w, Permissions_form.t) t
  | Set_permissions : (unit Entry.Id.t -> Permissions_form.t -> 'w, 'w, unit) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Get_type -> literal "get-type" @@ variable (module Entry.Id.S(SUnit)) @@ post (module Model_builder.Core.Any.Type)
    | Get_rows -> literal "get-rows" @@ body "ids" (module JList(Any_id)) @@ post (module JList(Any_row))
    | Newest -> literal "newest" @@ query_json "limit" (module JInt) @@ get (module JList(Any_row))
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Any_query) @@ get (module Make_search_result(Any_row))
    | Search_context_5_10 -> literal "context" @@ query_json "query" (module Any_query) @@ query_json "element" (module Any_id) @@ get (module Make_search_context_result(Any_id))
    | Get_permissions -> literal "get-permissions" @@ variable (module Entry.Id.S(SUnit)) @@ get (module Permissions_form)
    | Set_permissions -> literal "set-permissions" @@ variable (module Entry.Id.S(SUnit)) @@ query_json "actors-list" (module Permissions_form) @@ post (module JUnit)
