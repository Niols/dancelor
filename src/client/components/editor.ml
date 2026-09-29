open Js_of_ocaml
open Nes
open Html
open Utils

(* Helpers *)

let local_storage_key ~key = key ^ "-editor"

let read_local_storage (type value)(type state) ~key (editor : (value, state) Component.s) =
  let module Editor = (val editor) in
  Option.value ~default: Editor.empty @@
  Js.Optdef.case Dom_html.window##.localStorage (fun () -> None) @@ fun local_storage ->
  Js.Opt.case (local_storage##getItem (Js.string (local_storage_key ~key))) (fun () -> None) @@ fun value ->
  Result.to_option @@ Editor.state_of_yojson @@ Yojson.Safe.from_string @@ Js.to_string value

let write_local_storage (type value)(type state) ~key (editor : (value, state) Component.s) value =
  let module Editor = (val editor) in
  Js.Optdef.iter Dom_html.window##.localStorage @@ fun local_storage ->
  local_storage##setItem
    (Js.string (local_storage_key ~key))
    (Js.string @@ Yojson.Safe.to_string @@ Editor.state_to_yojson value)

(* Mode *)

type ('result, 'state) mode =
  | Create of 'state
  | Create_with_local_storage
  | Quick_create of string * ('result -> unit Lwt.t)
  | Edit of 'result
  | Quick_edit of 'state
[@@deriving variants]

(* Prepared editors *)

type ('result, 'value, 'state) s = {
  key: string;
  icon: Icon.t;
  submit: (('result, 'state) mode -> 'value -> 'result Lwt.t);
  unsubmit: ('result -> 'value Lwt.t);
  preview: ('value -> bool Lwt.t);
  format: ('result -> Html_types.div_content_fun Html.elt);
  href: ('result -> Uri.t);
  component: ('value, 'state) Component.s;
}

let key {key; _} = key
let empty (type value)(type state) {component = ((module C): (value, state) Component.s); _} : state = C.empty
let state_of_yojson (type value)(type state) {component = ((module C): (value, state) Component.s); _} = C.state_of_yojson
let state_to_yojson (type value)(type state) {component = ((module C): (value, state) Component.s); _} = C.state_to_yojson
let result_to_state (type result)(type value)(type state) : (result, value, state) s -> result -> state Lwt.t = fun {component = (module C); unsubmit; _} value ->
  unsubmit value >>= C.value_to_state

let prepare ~key ~icon ~submit ~unsubmit ?(preview = (fun _ -> lwt_true)) ~format ~href component =
  {key; icon; submit; unsubmit; preview; format; href; component}

let prepare_nosubmit ~key ~icon ?preview ~format ~href bundle =
  prepare ~key ~icon ~submit: (const lwt) ~unsubmit: lwt ?preview ~format ~href bundle

(* Initialised editors *)

type ('result, 'value, 'state) t = {
  s: ('result, 'value, 'state) s;
  mode: ('result, 'state) mode;
  page:
  (?after_save: (unit -> unit Lwt.t) ->
  ?title_suffix: string ->
  ?pre_body: Html_types.div_content_fun elt list ->
  ?post_body: Html_types.div_content_fun elt list ->
  unit ->
  Page.t Lwt.t);
  editor: ('value, 'state) Component.t;
}
[@@deriving fields]

let s e = e.s
let state e = Component.state e.editor
let set e r = Component.set e.editor =<< e.s.unsubmit r
let clear e = Component.clear e.editor

let signal e = Component.signal e.editor

let page ?after_save ?title_suffix ?pre_body ?post_body e =
  e.page ?after_save ?title_suffix ?pre_body ?post_body ()

let initialise (type result)(type value)(type state)
    (editor_s : (result, value, state) s)
    (mode : (result, state) mode)
    : (result, value, state) t Lwt.t
  =
  let {key; icon; submit; unsubmit; preview; format; href; component} = editor_s in
  let module C = (val component) in

  (* Determine the initial value of the editor. If there is an initial text,
     then we create it from that. If not, we retrieve a maybe-existing value
     from the local storage. *)
  let%lwt initial_value =
    match mode with
    | Create state -> lwt state
    | Create_with_local_storage -> lwt @@ read_local_storage ~key component
    | Quick_create (initial_text, _) -> lwt @@ C.from_initial_text initial_text
    | Edit entry -> C.value_to_state =<< unsubmit entry
    | Quick_edit state -> lwt state
  in

  (* Now that we have an initial value, we can actually initialise the editor to
     get things running. *)
  let%lwt editor = Component.initialise component initial_value in

  (* Enable saving the state whenever the editor changes. *)
  (
    match mode with
    | Create _ | Quick_create _ | Quick_edit _ | Edit _ -> ()
    | Create_with_local_storage ->
      let store = write_local_storage ~key component in
      let iter = S.map store @@ Component.state editor in
      (* NOTE: Depending on the promise breaks eventually. Depending on the editor
        seems to live as long as the page lives. *)
      Depart.depends ~on: editor iter
  );

  (* What to do when “save” is clicked. *)
  let save ?(after_save = fun () -> Component.clear editor) f =
    let%lwt result =
      match S.value @@ Component.signal editor with
      | Error _ -> lwt_none
      | Ok value ->
        match%lwt preview value with
        | false -> lwt_none
        | true -> some <$> submit mode value
    in
    Option.fold
      result
      ~none: lwt_unit
      ~some: (fun result -> after_save ();%lwt f result)
  in
  let save_buttons ?after_save () =
    let button ?label f =
      Button.save
        ?label
        ~disabled: (S.map Result.is_error (Component.signal editor))
        ~onclick: (fun () -> save ?after_save f)
        ()
    in
    let show_toast result =
      Toast.open_
        ~title: (String.capitalize_ascii key ^ " created")
        [txt ("The " ^ key ^ " ");
        format result;
        txt " has been created successfully.";
        ]
        ~buttons: [
          Button.make_a
            ~label: ("Go to " ^ key)
            ~icon
            ~classes: ["btn-primary"]
            ~href: (S.const @@ href result)
            ();
        ]
    in
    let redirect result =
      Dom_html.window##.location##.href := Js.string (Uri.to_string @@ href result)
    in
    match mode with
    | Create _ | Create_with_local_storage ->
      [
        button ~label: "Save and stay" (lwt % show_toast);
        button ~label: "Save and see" (lwt % redirect);
      ]
    | Quick_create (_, on_save) -> [button on_save]
    | Edit _ -> [button (lwt % redirect)]
    | Quick_edit _ -> [button (const lwt_unit)]
  in

  (* Make a page holding the editor and the appropriate buttons and actions. *)
  let page ?after_save ?(title_suffix = "") ?(pre_body = []) ?(post_body = []) () =
    Page.make'
      ~title: (
        lwt @@
        (
          match mode with
          | Create _ | Create_with_local_storage | Quick_create _ -> "Add a " ^ key
          | Quick_edit _ | Edit _ -> "Edit a " ^ key
        ) ^
        title_suffix
      )
      ~on_load: (fun () -> Component.focus editor)
      (pre_body @ [Component.inner_html editor] @ post_body)
      ~buttons: (
        Button.clear
          ~onclick: (fun () -> Component.clear editor)
          () :: save_buttons ?after_save ()
      )
  in

  (* Return the fully built editor. *)
  lwt {s = editor_s; mode; page; editor}

(* All-in-one function *)

let make_page
    ~key
    ~icon
    ~submit
    ~unsubmit
    ?preview
    ~format
    ~href
    ~mode
    ?after_save
    ?title_suffix
    ?pre_body
    ?post_body
    bundle
  =
  page ?after_save ?title_suffix ?pre_body ?post_body
  =<< initialise (prepare ~key ~icon ~submit ~unsubmit ?preview ~format ~href bundle) mode
