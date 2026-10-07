open Nes
open Dancelor_common

let call endpoint = Madge_client.call (Endpoints.Api.route endpoint)
let call_exn endpoint = Madge_client.call_exn (Endpoints.Api.route endpoint)

(** Like {!call} but returns an option; [Some] on success, [None] on 404 not
    found, other errors are exceptions. *)
let call_or_option endpoint id =
  Lwt.flip_map (call endpoint id) @@ function
    | Ok v -> Some v
    | Error (Madge_client.Http {status = `Not_found; _}) -> None
    | Error e -> raise (Madge_client.Error e)

let person_search slice input =
  match Person_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Person Search) slice query

let source_search slice input =
  match Source_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Source Search) slice query

let dance_search slice input =
  match Dance_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Dance Search) slice query

let version_search slice input =
  match Version_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Version Search) slice query

let tune_search slice input =
  match Tune_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Tune Search) slice query

let set_search slice input =
  match Set_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Set Search) slice query

let book_search slice input =
  match Book_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Book Search) slice query

let user_search slice input =
  match User_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (User Search) slice query

let group_search slice input =
  match Group_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Group Search) slice query

let entity_search slice input =
  match Resource_query.parse input with
  | Error msg -> lwt_error msg
  | Ok query -> ok <$> call_exn (Entity Search_resources) slice query
