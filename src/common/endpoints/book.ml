open Nes
open Madge
open Model_new
open Search

type (_, _, _) t =
  | Get_row : (Book_id.t -> 'w, 'w, Book_row.t) t
  | Get_view : (Book_id.t -> 'w, 'w, Book_view.t) t
  | Get_form : (Book_id.t -> 'w, 'w, Book_form.t) t
  | Get_rows : (Book_id.t list -> 'w, 'w, Book_row.t list) t
  | Search : (Slice.t -> Book_query.t -> 'w, 'w, Book_row.t Search_result.t) t
  | Create : (Book_form.t -> 'w, 'w, Book_id.t) t
  | Update : (Book_id.t -> Book_form.t -> 'w, 'w, unit) t
  | Add_version_to_contents : (Book_id.t -> Version_id.t -> 'w, 'w, unit) t
  | Add_set_to_contents : (Book_id.t -> Set_id.t -> 'w, 'w, unit) t
  | Add_dance_to_contents : (Book_id.t -> Dance_id.t -> 'w, 'w, unit) t
  | Delete : (Book_id.t -> 'w, 'w, unit) t
  | Build_pdf : (Book_id.t -> Book_parameters.t -> Rendering_parameters.t -> 'w, 'w, Job_id.t Job.registration_response) t
  | Build_zip : (Book_id.t -> Book_parameters.t -> Rendering_parameters.t -> 'w, 'w, Job_id.t Job.registration_response) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Get_row -> variable (module Book_id) @@ literal "row" @@ get (module Book_row)
    | Get_view -> variable (module Book_id) @@ literal "view" @@ get (module Book_view)
    | Get_form -> variable (module Book_id) @@ literal "form" @@ get (module Book_form)
    | Get_rows -> literal "rows" @@ body "ids" (module JList(Book_id)) @@ post (module JList(Book_row))
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module Book_query) @@ get (module Make_search_result(Book_row))
    | Create -> body "book" (module Book_form) @@ post (module Book_id)
    | Update -> variable (module Book_id) @@ body "book" (module Book_form) @@ put (module JUnit)
    | Add_version_to_contents -> variable (module Book_id) @@ body "version" (module Version_id) @@ put (module JUnit)
    | Add_set_to_contents -> variable (module Book_id) @@ body "set" (module Set_id) @@ put (module JUnit)
    | Add_dance_to_contents -> variable (module Book_id) @@ body "dance" (module Dance_id) @@ put (module JUnit)
    | Delete -> variable (module Book_id) @@ delete (module JUnit)
    | Build_pdf -> literal "build-pdf" @@ variable (module Book_id) @@ query_json_def "parameters" (module Book_parameters) ~eq: Book_parameters.equal ~def: Book_parameters.none @@ query_json_def "rendering-parameters" (module Rendering_parameters) ~eq: Rendering_parameters.equal ~def: Rendering_parameters.none @@ post (module Job.Registration_response(Job_id))
    | Build_zip -> literal "build-zip" @@ variable (module Book_id) @@ query_json_def "parameters" (module Book_parameters) ~eq: Book_parameters.equal ~def: Book_parameters.none @@ query_json_def "rendering-parameters" (module Rendering_parameters) ~eq: Rendering_parameters.equal ~def: Rendering_parameters.none @@ post (module Job.Registration_response(Job_id))
