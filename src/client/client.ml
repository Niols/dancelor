open Js_of_ocaml
open Nes
open Dancelor_common
open Html
open Utils
open Views

module Log = (val Logs.src_log @@ Logs.Src.create "client": Logs.LOG)

let () = Madge_client.initialise_batch_route Endpoints.Api.(route_full Batch)

let redirect_entity id =
  (* FIXME: The preloaded API payload here could redirect to the right page. *)
  Main_page.madge_call_or_404 (Entity Resource_type) id @@ fun type_ ->
  Redirection_viewer.create @@ Endpoints.Page.href_entity_full @@ Resource_id.of_untagged type_ id

let dispatch ~preloaded_api_payload =
  let dispatch : type a r. (a, Page.t Lwt.t, r) Endpoints.Page.t -> a = function
    | Index -> Index.create ()
    | Entity -> redirect_entity ~preloaded_api_payload
    | Explore -> Explorer.view
    | Book Add -> Book_editor.add ()
    | Book Edit -> Book_editor.edit
    | Book View -> Book_viewer.view ~preloaded_api_payload
    | Book Preview -> Book_viewer.preview ~preloaded_api_payload
    | Dance View -> Dance_viewer.view ~preloaded_api_payload
    | Dance Add -> Dance_editor.add ()
    | Dance Edit -> Dance_editor.edit
    | Person View -> Person_viewer.view ~preloaded_api_payload
    | Person Add -> Person_editor.add ()
    | Person Edit -> Person_editor.edit
    | Version View -> Version_viewer.view_version ~preloaded_api_payload
    | Version Add -> Version_editor.add
    | Version Edit -> Version_editor.edit
    | Tune View -> Version_viewer.view_tune ~preloaded_api_payload
    | Tune Add -> Tune_editor.add ()
    | Tune Edit -> Tune_editor.edit
    | Set View -> Set_viewer.view ~preloaded_api_payload
    | Set Add -> Set_editor.add ()
    | Set Edit -> Set_editor.edit
    | Source View -> Source_viewer.view ~preloaded_api_payload
    | Source Add -> Source_editor.add ()
    | Source Edit -> Source_editor.edit
    | User View -> User_viewer.view ~preloaded_api_payload
    | User Edit -> User_editor.edit
    | User Create -> User_creator.create ()
    | User Prepare_reset_password -> User_password_reset_preparer.create ()
    | User Password_reset -> User_password_resetter.create
    | Group View -> Group_viewer.view ~preloaded_api_payload
    | Group Create -> Group_editor.add ()
    | Group Edit -> Group_editor.edit
    | Admin Users_and_groups -> Admin_users_and_groups.view ()
  in
  let route = Endpoints.Page.route in
  let no_route () = Oooops_viewer.create `Not_found in
  Endpoints.Page.match_ {route; no_route; dispatch}

let dispatch uri = dispatch (Madge.Request.make ~meth: GET ~uri ~body: "")

let setup_offline_detector () =
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

let setup_async_exception_hook () =
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

let run (preloaded_api_payload : string) =
  Logger.bracket (module Log) "starting client" @@ fun () ->
  Random.self_init ();
  setup_offline_detector ();
  setup_async_exception_hook ();
  Logger.full_initialisation
    ~reporter: (Logs_browser.console_reporter ())
    (Logger.make_loglevel_map ());
  Log.debug (fun m -> m "Payload: %s" preloaded_api_payload);
  let uri = get_uri () in
  History.add uri;
  Main_page.initialise ();
  Lwt.async (fun () -> Main_page.load @@ dispatch ~preloaded_api_payload uri)

let () =
  Js.export
    "dancelorClient"
    (
      object%js
        method run payload = run payload
      end
    )
