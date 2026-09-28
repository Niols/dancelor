open Nes
open Dancelor_common

open Endpoints.Issue_report
open Request

include Endpoints.Page.Make_describe(Model)

(* used at the end of the {!report} function below *)
let id_regexp = Str.regexp ".*/issues/\\(.*\\)"

let report env issue =
  let%lwt (repo, title) =
    if issue.source_is_dancelor then
      lwt ((Config.get ()).github_repository, issue.title)
    else
      let%lwt (model, name) = Option.get <$> describe issue.page in
      lwt ((Config.get ()).github_database_repository, Format.sprintf "%s “%s”: %s" model name issue.title)
  in
  assert (repo <> "");
  (* otherwise this will pick up on the current Git repository *)
  let body =
    spf
      "**Reporter**: %s\n\n**Page**: %s\n%s"
      (
        match issue.reporter with
        | Left `Connected ->
          (
            match Environment.actor env with
            | Signed_in actor ->
              (* FIXME: when there is a profile page for users, link to it *)
              (Username.to_string @@ Model.User.username' actor) ^
                (match Model.User.github_handle' actor with None -> "" | Some handle -> spf " (@%s)" handle)
            | Anonymous -> "(claiming to be connected but is not)"
          )
        | Right string -> string ^ " (not connected)"
      )
      (Uri.to_string issue.page)
      (
        if issue.description = "" then ""
        else spf "\n**Description**:\n\n%s\n" issue.description
      )
  in
  let%lwt output =
    NesProcess.run
      ~env: [|
        "PATH=" ^ (Unix.getenv "PATH");
        "GH_TOKEN=" ^ (Config.get ()).github_token;
      |]
      ~on_wrong_status: Logs.Error
      ~on_nonempty_stderr: Logs.Error
      ["gh"; "issue"; "create"; "--repo"; repo; "--title"; title; "--body"; body]
  in
  let uri = String.trim output.stdout in
  assert (Str.string_match id_regexp uri 0);
  let id = int_of_string @@ Str.matched_group 1 uri in
  let uri = Uri.of_string uri in
  lwt Response.{title; id; uri}
