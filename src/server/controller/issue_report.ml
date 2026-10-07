open Nes
open Dancelor_common
open Endpoints.Issue_report
open Request

include Endpoints.Page.Make_describe(struct
  type env = Environment.t
  let get_person_name env id = Person_row.name <$> Person.get_row env id
  let get_dance_name env id = Dance_row.name <$> Dance.get_row env id
  let get_source_name env id = Source_row.name <$> Source.get_row env id
  let get_tune_name env id = Tune_row.name <$> Tune.get_row env id
  let get_version_name env id = Tune_row.name % Version_row.tune <$> Version.get_row env id
  let get_set_name env id = Set_row.name <$> Set.get_row env id
  let get_book_name env id = Book_row.name <$> Book.get_row env id
  let get_user_name env id = Username.to_string % User_row.username <$> User.get_row env id
  let get_group_name env id = Group_row.name <$> Group.get_row env id
end)

(* used at the end of the {!report} function below *)
let id_regexp = Str.regexp ".*/issues/\\(.*\\)"

let report env issue =
  let%lwt (repo, title) =
    if issue.source_is_dancelor then
      lwt ((Config.get ()).github_repository, issue.title)
    else
      let%lwt (model, name) = Option.get <$> describe env issue.page in
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
              (Username.to_string actor.username) ^
                (match actor.github_handle with None -> "" | Some handle -> spf " (@%s)" handle)
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
