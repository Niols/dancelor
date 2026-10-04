open Nes
open Madge
open Model_new
open Search_new

type (_, _, _) t =
  | Get_row : (Tune_id.t -> 'w, 'w, Tune_row.t) t
  | Get_view : (Tune_id.t -> 'w, 'w, Tune_view.t) t
  | Get_form : (Tune_id.t -> 'w, 'w, Tune_form.t) t
  | Search : (Slice.t -> Tune_query.t -> 'w, 'w, Tune_row.t Search_result.t) t
  | Create : (Tune_form.t -> 'w, 'w, Tune_id.t) t
  | Update : (Tune_id.t -> Tune_form.t -> 'w, 'w, unit) t
  | Delete : (Tune_id.t -> 'w, 'w, unit) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Get_row -> variable (module Tune_id) @@ literal "row" @@ get (module Tune_row)
    | Get_view -> variable (module Tune_id) @@ literal "view" @@ get (module Tune_view)
    | Get_form -> variable (module Tune_id) @@ literal "form" @@ get (module Tune_form)
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Tune_query) @@ get (module Make_search_result(Tune_row))
    | Create -> body "tune" (module Tune_form) @@ post (module Tune_id)
    | Update -> variable (module Tune_id) @@ body "tune" (module Tune_form) @@ put (module JUnit)
    | Delete -> variable (module Tune_id) @@ delete (module JUnit)
