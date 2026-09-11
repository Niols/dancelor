open Js_of_ocaml
open Nes
open Html
open Utils

(* Bundles *)

type ('value, 'state) bundle = Bundle of ('value, 'state) Component.s

let cons (type value1)(type state1)(type value2)(type state2)
    (component : (value1, state1) Component.s)
    (Bundle bundle: (value2, state2) bundle)
    : (value1 * value2, state1 * state2) bundle
  =
  Bundle (module struct
    include (val Cpair.bundle ~wrap: id ~unwrap: id component bundle)

    let inner_html p =
      div [
        Component.html' (module C1) (c1 p);
        C2.inner_html (c2 p);
      ]
  end)

let (^::) = cons
let nil : (unit, unit) bundle = Bundle (Nil.prepare ())

(* Helpers *)

exception Non_convertible

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

type ('result, 'product, 'value, 'state) s = {
  key: string;
  icon: Icon.t;
  assemble: ('value -> 'product);
  submit: (('result, 'state) mode -> 'product -> 'result Lwt.t);
  unsubmit: ('result -> 'product Lwt.t);
  disassemble: ('product -> 'value Lwt.t);
  preview: ('product -> bool Lwt.t);
  format: ('result -> Html_types.div_content_fun Html.elt);
  href: ('result -> Uri.t);
  bundle: ('value, 'state) bundle;
}

let key {key; _} = key
let empty (type value)(type state) {bundle = (Bundle(module C): (value, state) bundle); _} : state = C.empty
let state_of_yojson (type value)(type state) {bundle = (Bundle(module C): (value, state) bundle); _} = C.state_of_yojson
let state_to_yojson (type value)(type state) {bundle = (Bundle(module C): (value, state) bundle); _} = C.state_to_yojson
let result_to_state (type result)(type value)(type state) : (result, 'product, value, state) s -> result -> state Lwt.t = fun {bundle = Bundle(module C); unsubmit; disassemble; _} value ->
  unsubmit value >>= disassemble >>= C.value_to_state

let prepare ~key ~icon ~assemble ~submit ~unsubmit ~disassemble ~check_product ?(preview = (fun _ -> lwt_true)) ~format ~href bundle =
  (* pimped version of [disassemble] that checks the roundtrip *)
  let disassemble product =
    let%lwt value = disassemble product in
    let product' = assemble value in
    if not (check_product product product') then
      raise Non_convertible;
    lwt value
  in
    {key; icon; assemble; submit; unsubmit; disassemble; preview; format; href; bundle}

let prepare_nosubmit ~key ~icon ~assemble ~disassemble ~check_result ?preview ~format ~href bundle =
  prepare ~key ~icon ~assemble ~submit: (const lwt) ~unsubmit: lwt ~disassemble ~check_product: check_result ?preview ~format ~href bundle

(* Initialised editors *)

type ('result, 'product, 'value, 'state) t = {
  s: ('result, 'product, 'value, 'state) s;
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
let set e r = Component.set e.editor <=< e.s.disassemble =<< e.s.unsubmit r
let clear e = Component.clear e.editor

let signal e =
  RS.bind (Component.signal e.editor) @@ fun value ->
  RS.pure (e.s.assemble value)

let page ?after_save ?title_suffix ?pre_body ?post_body e =
  e.page ?after_save ?title_suffix ?pre_body ?post_body ()

let initialise (type result)(type value)(type product)(type state)
    (editor_s : (result, product, value, state) s)
    (mode : (result, state) mode)
    : (result, product, value, state) t Lwt.t
  =
  let {key; icon; assemble; submit; unsubmit; disassemble; preview; format; href; bundle} = editor_s in
  let Bundle bundle = bundle in
  let module Bundle = (val bundle) in

  (* Determine the initial value of the editor. If there is an initial text,
     then we create it from that. If not, we retrieve a maybe-existing value
     from the local storage. *)
  let%lwt initial_value =
    match mode with
    | Create state -> lwt state
    | Create_with_local_storage -> lwt @@ read_local_storage ~key bundle
    | Quick_create (initial_text, _) -> lwt @@ Bundle.from_initial_text initial_text
    | Edit entry -> Bundle.value_to_state <=< disassemble =<< unsubmit entry
    | Quick_edit state -> lwt state
  in

  (* Now that we have an initial value, we can actually initialise the editor to
     get things running. *)
  let%lwt editor = Component.initialise bundle initial_value in

  (* Enable saving the state whenever the editor changes. *)
  (
    match mode with
    | Create _ | Quick_create _ | Quick_edit _ | Edit _ -> ()
    | Create_with_local_storage ->
      let store = write_local_storage ~key bundle in
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
        let product = assemble value in
        match%lwt preview product with
        | false -> lwt_none
        | true -> some <$> submit mode product
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
    ~assemble
    ~submit
    ~unsubmit
    ~disassemble
    ~check_product
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
  =<< initialise (prepare ~key ~icon ~assemble ~submit ~unsubmit ~disassemble ~check_product ?preview ~format ~href bundle) mode
