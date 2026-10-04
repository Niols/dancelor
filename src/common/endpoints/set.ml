open Nes
open Madge
open Model_new
open Search

type (_, _, _) t =
  | Get_row : (Set_id.t -> 'w, 'w, Set_row.t) t
  | Get_view : (Set_id.t -> 'w, 'w, Set_view.t) t
  | Get_rows : (Set_id.t list -> 'w, 'w, Set_row.t list) t
  | Get_form : (Set_id.t -> 'w, 'w, Set_form.t) t
  | Search : (Slice.t -> Set_query.t -> 'w, 'w, Set_row.t Search_result.t) t
  | Create : (Set_form.t -> 'w, 'w, Set_id.t) t
  | Update : (Set_id.t -> Set_form.t -> 'w, 'w, unit) t
  | Add_version_to_contents : (Set_id.t -> Version_id.t -> 'w, 'w, unit) t
  | Delete : (Set_id.t -> 'w, 'w, unit) t
  | Build_pdf : (Set_id.t -> Set_parameters.t -> Rendering_parameters.t -> 'w, 'w, Job_id.t Job.registration_response) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Get_row -> variable (module Set_id) @@ literal "row" @@ get (module Set_row)
    | Get_view -> variable (module Set_id) @@ literal "view" @@ get (module Set_view)
    | Get_form -> variable (module Set_id) @@ literal "form" @@ get (module Set_form)
    | Get_rows -> literal "rows" @@ body "ids" (module JList(Set_id)) @@ post (module JList(Set_row))
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Set_query) @@ get (module Make_search_result(Set_row))
    | Create -> body "set" (module Set_form) @@ post (module Set_id)
    | Update -> variable (module Set_id) @@ body "set" (module Set_form) @@ put (module JUnit)
    | Add_version_to_contents -> variable (module Set_id) @@ body "version" (module Version_id) @@ put (module JUnit)
    | Delete -> variable (module Set_id) @@ delete (module JUnit)
    | Build_pdf -> literal "build-pdf" @@ variable (module Set_id) @@ query_json_def "parameters" (module Set_parameters) ~eq: Set_parameters.equal ~def: Set_parameters.none @@ query_json_def "rendering-parameters" (module Rendering_parameters) ~eq: Rendering_parameters.equal ~def: Rendering_parameters.none @@ post (module Job.Registration_response(Job_id))
