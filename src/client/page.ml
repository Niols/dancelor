open Dancelor_common
open Model_new
open Js_of_ocaml
open Nes
open Html
open Utils

type t = {
  parent_title: string;
  before_title: Html_types.div_content_fun elt list;
  title: string Lwt.t;
  subtitles: Html_types.phrasing elt list;
  content: Html_types.div_content_fun elt list;
  share: Any_id.t option;
  actions: Html_types.li_content_fun elt list Lwt.t list;
  buttons: Html_types.div_content_fun elt list;
  on_load: unit -> unit;
}

let full_title p =
  S.map
    (function
      | "" -> p.parent_title
      | title ->
        match p.parent_title with
        | "" -> title
        | _ -> title ^ " | " ^ p.parent_title
    )
    (S.from_lwt "" p.title)

let make
  ?(parent_title = "")
  ?(before_title = [])
  ~title
  ?(subtitles = [])
  ?share
  ?(actions = [])
  ?(buttons = [])
  ?(on_load = Fun.id)
  content
=
  {parent_title; before_title; title; subtitles; content; share; actions; buttons; on_load}

let make' ?parent_title ?before_title ~title ?subtitles ?share ?actions ?buttons ?on_load content =
  (* NOTE: In general, [lwt] for no reason should be avoided. However, this
     particular function is only ever used in an [Lwt] context. *)
  lwt @@ make ?parent_title ?before_title ~title ?subtitles ?share ?actions ?buttons ?on_load content

let render p =
  (* Handling of actions. We could probably generate the <ul> elements gradually
     rather than waiting for all the promises, but what difference would it make. *)
  let actions_promise = List.(map (li % singleton) % concat) <$> Lwt_list.map_p id p.actions in
  let actions_html =
    R.div
      ~a: [a_class ["dropdown"; "m-0"; "ms-2"; "p-0"; "col-auto"; "d-flex"; "flex-column"; "flex-sm-row"; "align-items-start"]]
      (
        S.l2
          (@)
          (
            S.const @@
              match p.share with
              | None -> []
              | Some share ->
                [
                  Button.make
                    ~icon: (Action Share)
                    ~classes: ["btn-primary"]
                    ~onclick: (fun _ ->
                      write_to_clipboard @@ href_any_for_sharing_new share;
                      Toast.open_ ~title: "Copied to clipboard" [txt "A short link to this page has been copied to your clipboard."];
                      lwt_unit
                    )
                    ()
                ]
          )
          (
            S.from_lwt [] @@
            Lwt.flip_map actions_promise @@ function
            | [] -> []
            | actions ->
              [
                Button.make
                  ~icon: (Other Actions)
                  ~classes: ["btn-secondary"]
                  ~more_a: [a_user_data "bs-toggle" "dropdown"]
                  ();
                ul ~a: [a_class ["dropdown-menu"]] actions
              ]
          )
      )
  in
  let actions_mirror =
    (* invisible buttons of the same size as actions_html *)
    R.div ~a: [a_class ["invisible"; "d-none"; "d-sm-block"; "me-0"; "me-sm-2"]] (
      S.l2
        (@)
        (
          S.const @@
            match p.share with
            | None -> []
            | Some _ -> [Button.make ~icon: (Action Share) ()]
        )
        (
          S.from_lwt [] @@
          Lwt.flip_map actions_promise @@ function
          | [] -> []
          | _ -> [Button.make ~icon: (Other Actions) ()]
        )
    )
  in

  (* Result *)
  (
    p.on_load,
    div
      [
        div p.before_title;
        div
          ~a: [a_class ["container-md"]]
          [
            div ~a: [a_class ["d-flex"; "justify-content-between"]] [
              actions_mirror;
              div ~a: [a_class ["text-center"; "col"]] [
                h1 [with_span_placeholder @@ ((List.singleton % txt) <$> p.title)];
                div (List.map (h5 % List.singleton) p.subtitles);
              ];
              actions_html;
            ];
            div ~a: [a_class ["mt-4"]] p.content;
            match p.buttons with
            | [] -> div []
            | buttons ->
              (* NOTE: [intersperse (txt " ")] wouldn't work because it would be
                 the exact same Dom element. *)
              div
                ~a: [a_class ["d-flex"; "justify-content-end"; "mt-4"]]
                [div (List.interspersei (fun _ -> txt " ") buttons)]
          ];
      ]
  )

let open_dialog
    ?(hide_body_overflow_y = false)
    make_page
  =
  let (promise, resolver) = Lwt.wait () in

  (* The actual [return] function requires a handle of the box to work, but the
     box itself needs to be able to call [return]; hence this dirty trick. *)
  let box_handle = ref None in
  let return v =
    match !box_handle with
    | None -> failwith "Dialog.open_: use of `return` before full initialisation"
    | Some box ->
      Lwt.wakeup_later resolver v;
      Dom.removeChild Dom_html.document##.body box
  in
  let%lwt page = make_page return in
  assert (page.subtitles = []);

  (* The HTML dialog box. *)
  let box =
    (* NOTE: the `d-block` is a hack to make the element show; we should figure
       out how to tell Bootstrap to show the element directly. Similarly, the
       custom style is because I could not figure out how to show get the
       background from Bootstrap. *)
    div
      ~a: [
        a_class ["modal"; "d-block"];
        a_tabindex (-1);
        a_style "background: rgba(0, 0, 0, 0.5);";
      ]
      [
        div
          ~a: [a_class ["modal-dialog"; "modal-lg"; "modal-fullscreen-lg-down"; "modal-dialog-centered"; "modal-dialog-scrollable"]]
          [
            div
              ~a: [a_class ["modal-content"]]
              [
                div
                  ~a: [a_class ["modal-header"]]
                  [
                    h4 ~a: [a_class ["modal-title"]] [
                      with_span_placeholder @@
                        let%lwt title = page.title in
                        lwt [txt title]
                    ];
                    button
                      ~a: [
                        a_button_type `Button;
                        a_class ["btn-close"];
                        a_user_data "bs-dismiss" "modal";
                        a_aria "label" ["Close"];
                        a_onclick (fun _ -> return None; false);
                      ]
                      [];
                  ];
                div
                  ~a: [a_class (["modal-body"] @ (if hide_body_overflow_y then ["overflow-y-hidden"] else []))]
                  (page.before_title @ page.content);
                div ~a: [a_class ["modal-footer"]] page.buttons;
              ];
          ];
      ]
  in
  let dom_box = To_dom.of_div box in
  box_handle := Some dom_box;

  (* Add the box as a child of `<body>`. *)
  Dom.appendChild Dom_html.document##.body dom_box;

  (* FIXME: When the dialog disappears, this event will stick around. Avoid
     EventListeners for elements that might disappear, unless really necessary.
     In this case, we can probably track [onclick] on the whole modal, since the
     background takes everything. *)
  (* Add an event listener to close the box by clicking outside of it. *)
  add_target_event_listener Dom_html.window Dom_html.Event.click (fun _event target ->
    if target = (dom_box :> Dom_html.element Js.t) then
      return None;
    Js._true
  );

  (* Trigger the [on_load] property of the page. *)
  page.on_load ();

  (* Return the promise of a result. *)
  promise

let open_dialog' make_page =
  open_dialog (fun return -> make_page (return % some))
