open Js_of_ocaml
open Nes
open Dancelor_common
open Html
open Utils
open Views

module Log = (val Logs.src_log @@ Logs.Src.create "client": Logs.LOG)

let get_uri () = Uri.of_string (Js.to_string Dom_html.window##.location##.href)

let redirect_any id =
  Main_page.madge_call_or_404 (Any Get_type) id @@ fun type_ ->
  Redirection_viewer.create @@ Endpoints.Page.href_any_full @@ Any_id.of_untagged type_ id

let () = Madge_client.initialise_batch_route Endpoints.Api.(route_full Batch)

let dispatch uri =
  let dispatch : type a r. (a, Page.t Lwt.t, r) Endpoints.Page.t -> a = function
    | Index -> Index.create ()
    | Any -> redirect_any
    | Explore -> Explorer.view
    | Book Add -> Book_editor.add ()
    | Book Edit -> Book_editor.edit
    | Book View -> Book_viewer.view
    | Book Preview -> Book_viewer.preview
    | Dance View -> Dance_viewer.view
    | Dance Add -> Dance_editor.add ()
    | Dance Edit -> Dance_editor.edit
    | Person View -> Person_viewer.view
    | Person Add -> Person_editor.add ()
    | Person Edit -> Person_editor.edit
    | Version View -> Version_viewer.view_version
    | Version Add -> Version_editor.add
    | Version Edit -> Version_editor.edit
    | Tune View -> Version_viewer.view_tune
    | Tune Add -> Tune_editor.add ()
    | Tune Edit -> Tune_editor.edit
    | Set View -> Set_viewer.view
    | Set Add -> Set_editor.add ()
    | Set Edit -> Set_editor.edit
    | Source View -> Source_viewer.view
    | Source Add -> Source_editor.add ()
    | Source Edit -> Source_editor.edit
    | User View -> User_viewer.view
    | User Edit -> User_editor.edit
    | User Create -> User_creator.create ()
    | User Prepare_reset_password -> User_password_reset_preparer.create ()
    | User Password_reset -> User_password_resetter.create
  in
  let madge_match_apply_all : Page.t Lwt.t Endpoints.Page.wrapped' list -> (unit -> Page.t Lwt.t) option =
    List.find_map @@ fun (Endpoints.Page.W' endpoint) ->
    Madge.apply' (Endpoints.Page.route endpoint) (fun () -> dispatch endpoint) (Madge.Request.make ~meth: GET ~uri ~body: "")
  in
  match madge_match_apply_all @@ Endpoints.Page.all' () with
  | Some page -> page ()
  | None -> Oooops_viewer.create `Not_found

let () = Random.self_init ()

let () =
  Depart.keep_forever @@
    React.E.map
      (function
        | Environment.Reachable ->
          Toast.open_
            ~title: "You are back online"
            [txt "The Dancelor server could be reached again. You are back online."]
        | Environment.Unreachable ->
          Toast.open_
            ~title: "You are now offline"
            [txt "The Dancelor server cannot be reached any more. You are now in offline mode."]
      )
      (S.changes Environment.server_status)

let () =
  let previous_exn = ref (Failure "this is an exception that is never raised") in
  Lwt.async_exception_hook :=
    (fun exn ->
      if exn = !previous_exn then
        Log.debug (fun m -> m "Ignoring duplicate exception %s" (Printexc.to_string exn))
      else
        (
          previous_exn := exn;
          match exn with
          | Lwt.Canceled -> () (* the promises are cancelled on purpose *)
          | Main_page.Replacement_successful -> () (* see comment for {!Main_page.load_sleep_raise} *)
          | Madge_client.(Error (Http {request; status; _})) ->
            Toast.open_
              ~type_: Forever
              ~title: "Uncaught API call error"
              [
                txt "While querying ";
                a ~a: [a_href @@ Madge.Request.uri request] [txt @@ Uri.path @@ Madge.Request.uri request];
                txt ", Dancelor encountered “";
                txt (Cohttp.Code.string_of_status status);
                txt
                  "” and did not handle it gracefully. If the error persists, please \
               contact your administrator or file a bug report.";
              ]
          | Madge_client.(Error (Server_unreachable {request; status})) ->
            Toast.open_
              ~type_: Forever
              ~title: "Server unreachable"
              [
                txt "While querying ";
                a ~a: [a_href @@ Madge.Request.uri request] [txt @@ Uri.path @@ Madge.Request.uri request];
                txt ", the Dancelor server was unreachable (“";
                txt (Cohttp.Code.string_of_status status);
                txt
                  "”), despite several attempts. Is your internet connection \
                     maybe unstable? If the error persists, and your internet \
                     connection works otherwise fine, please contact your \
                     administrator."
              ]
          | exn ->
            (* NOTE: I wish I could show backtraces, but that just doesn't work in js_of_ocaml. *)
            Log.err (fun m -> m "Uncaught exception: %s" (Printexc.to_string exn));
            Toast.open_
              ~type_: Forever
              ~title: "Uncaught exception"
              [
                txt "Dancelor encountered";
                pre ~a: [a_class ["text-wrap"; "my-2"]] [txt @@ Printexc.to_string exn];
                txt
                  "and did not handle it gracefully. If the error persists, please \
               contact your administrator or file a bug report.";
              ]
        )
    )

let () =
  Logger.full_initialisation
    ~reporter: (Logs_browser.console_reporter ())
    {cases = []; default = Some Logs.Info}

let () =
  Dom_html.window##.onload :=
    Dom_html.handler (fun _ev ->
      Main_page.initialise ();
      Lwt.async (Main_page.load % dispatch % get_uri);
      Js._false
    )

let () = History.add @@ get_uri ()

let () = Log.info (fun m -> m "Client is up and running")
