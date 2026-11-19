open Nes
open Dancelor_common
open Js_of_ocaml
open Html
open Utils

module Log = (val Logs.src_log @@ Logs.Src.create "client.views.main-page": Logs.LOG)

let quick_search_to_explorer value =
  let href = Endpoints.Page.(href Explore) value 1 in
  Dom_html.window##.location##.href := Js.string (Uri.to_string href);
  Js_of_ocaml_lwt.Lwt_js.sleep 10.

let quick_search =
  Components.Search.Quick.make
    ~search: Api.resource_search
    ~on_enter: (fun value -> Lwt.async (fun () -> quick_search_to_explorer value))
    ()

let open_quick_search () =
  ignore
  <$> Page.open_dialog ~hide_body_overflow_y: true @@ fun return ->
    Components.Search.Quick.render
      ~return
      ~dialog_title: (lwt "Quick search")
      ~dialog_buttons: [
        Button.make
          ~label: "Explore"
          ~label_processing: "Opening explorer..."
          ~icon: (Action Search_more)
          ~badge: "↵"
          ~classes: ["btn-primary"]
          ~onclick: (fun () -> quick_search_to_explorer (S.value @@ Components.Search.Quick.text quick_search))
          ();
      ]
      ~make_result: (fun ?in_search result -> Tables.entity_row ?in_search result)
      quick_search

(** Add an onclick event to the search button, and an event listener to the
    whole window to open the quick search by pressing '/'. *)
let setup_quick_search () =
  let setup_quick_search_button platform =
    let quick_search_button : Dom.child_node =
      Dom.node @@
      To_dom.of_button @@
      Button.make
        ~icon: (Action Search)
        ?label: (match platform with `Mobile -> None | `Desktop -> Some "Search")
        ?badge: (match platform with `Mobile -> None | `Desktop -> Some "/")
        ~classes: (
          "btn-light" ::
          match platform with
          | `Mobile -> ["me-2"; "d-block"; "d-sm-none"]
          | `Desktop -> ["ms-2"; "d-none"; "d-sm-block"]
        )
        ~onclick: open_quick_search
        ()
    in
    let container = Dom_html.getElementById @@ Main_page_ids.quick_search_button_container_id platform in
    Dom.replaceChildren container [quick_search_button]
  in
  setup_quick_search_button `Mobile;
  setup_quick_search_button `Desktop;
  add_target_event_listener
    Dom_html.window
    Dom_html.Event.keydown
    (fun event target ->
      if not (is_input target) && event##.keyCode = 191 then (* slash *)
        (Lwt.async open_quick_search; Js._false)
      else
        Js._true
    )

let setup_issue_report () =
  let issue_report_button : Dom.child_node =
    Dom.node @@
    To_dom.of_button @@
    Button.make
      ~label: "Report an issue"
      ~label_processing: "Reporting..."
      ~icon: (Other Bug)
      ~classes: ["btn-light"; "my-1"]
      ~onclick: (fun () ->
        ignore <$> Issue_report.open_dialog @@ get_uri ()
      )
      ()
  in
  let container = Dom_html.getElementById Main_page_ids.issue_report_button_container_id in
  Dom.replaceChildren container [issue_report_button]

let setup_actor_header () =
  (* FIXME: More than this could go server-side *)
  let actor_header_item : Dom.child_node =
    Dom.node @@
    To_dom.of_li @@
    Actor_header.header_item
  in
  let container = Dom_html.getElementById Main_page_ids.actor_header_container_id in
  Dom.replaceChildren container [actor_header_item]

let initialise () =
  setup_quick_search ();
  setup_issue_report ();
  setup_actor_header ()

let load page_promise =
  let%lwt page = page_promise in
  let iter_title = React.S.map set_title (Page.full_title page) in
  Depart.keep_forever iter_title;
  let (page_on_load, page_content) = Page.render page in
  let page_content = Dom.node @@ To_dom.of_div page_content in
  let container = Dom_html.getElementById Main_page_ids.main_container_id in
  Dom.replaceChildren container [page_content];
  page_on_load ();
  lwt_unit

let madge_call_or_404 ~preloaded_api_payload endpoint arg f =
  let preloaded_value =
    try
      match Yojson.Safe.from_string preloaded_api_payload with
      | `Null -> None
      | preloaded_api_payload_json ->
        match Api.result_of_yojson endpoint preloaded_api_payload_json with
        | Error _ ->
          Log.warn (fun m -> m "Could not unserialise preloaded API payload: %s" preloaded_api_payload);
          None
        | Ok r -> Some r
    with
      | exn ->
        Log.warn (fun m -> m "Encountered exception while unserialising preloaded API payload: %s %s" (Printexc.to_string exn) preloaded_api_payload);
        None
  in
  match preloaded_value with
  | Some v -> f v
  | None ->
    try%lwt
      f =<< Api.call_exn endpoint arg
    with
      | Madge_client.(Error (Http {status; _})) -> Oooops_viewer.create status

let assert_can_create_public f =
  match%lwt Environment.actor with
  | Some _ -> f ()
  | None -> Oooops_viewer.create `Forbidden

let assert_can_create_private f =
  match%lwt Environment.actor with
  | Some _ -> f ()
  | None -> Oooops_viewer.create `Forbidden

let assert_can_update permission f =
  match Permission.edit_reason permission with
  | Some edit_reason -> f edit_reason
  | None -> Oooops_viewer.create `Forbidden

let can_update_public _ =
  match%lwt Environment.actor with
  | None -> lwt_none
  | Some actor ->
    (* FIXME: This is such a hack! [Permission_new] and [edit_reason] should be
       aware of maintainers and non-omniscient administrator. *)
    lwt @@
      Permission.edit_reason {
        actor_role = None;
        actor_is_omniscient_administrator = (actor.role = Maintainer || actor.role = Administrator);
        entity_is_public = true;
      }

let can_delete_public = can_update_public

let can_admin () =
  match%lwt Environment.actor with
  | Some actor when actor.role = Administrator -> lwt_true
  | _ -> lwt_false

let assert_can_admin f =
  if%lwt can_admin () then
    f ()
  else
    Oooops_viewer.create `Forbidden
