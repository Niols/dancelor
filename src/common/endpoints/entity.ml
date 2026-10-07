open Nes
open Madge
open Model
open Search

type (_, _, _) t =
  | Resource_type : (Untagged.t Id.t -> 'w, 'w, Resource_type.t) t
  | Resource_rows : (Resource_id.t list -> 'w, 'w, Resource_row.t list) t
  | Newest_resources : (int -> 'w, 'w, Resource_row.t list) t
  | Search_resources : (Slice.t -> Resource_query.t -> 'w, 'w, Resource_row.t Search_result.t) t
  | Search_resources_context_5_10 : (Resource_query.t -> Resource_id.t -> 'w, 'w, Resource_id.t Search_context_result.t) t
  | Get_permissions : (Untagged.t Id.t -> 'w, 'w, Permissions_form.t) t
  | Set_permissions : (Untagged.t Id.t -> Permissions_form.t -> 'w, 'w, unit) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Resource_type -> literal "get-type" @@ variable (module Id.S(Untagged)) @@ post (module Resource_type)
    | Resource_rows -> literal "get-rows" @@ body "ids" (module JList(Resource_id)) @@ post (module JList(Resource_row))
    | Newest_resources -> literal "newest" @@ query_json "limit" (module JInt) @@ get (module JList(Resource_row))
    | Search_resources -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Resource_query) @@ get (module Make_search_result(Resource_row))
    | Search_resources_context_5_10 -> literal "context" @@ query_json "query" (module Resource_query) @@ query_json "element" (module Resource_id) @@ get (module Make_search_context_result(Resource_id))
    | Get_permissions -> literal "get-permissions" @@ variable (module Id.S(Untagged)) @@ get (module Permissions_form)
    | Set_permissions -> literal "set-permissions" @@ variable (module Id.S(Untagged)) @@ query_json "actors-list" (module Permissions_form) @@ post (module JUnit)
