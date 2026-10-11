open Nes
open Js_of_ocaml
open Html
open Utils

type html =
  | Text of {input: 'a. ([> Html_types.input] as 'a) elt; input_dom: Dom_html.inputElement Js.t}
  | Textarea of {textarea: 'a. ([> Html_types.textarea] as 'a) elt; textarea_dom: Dom_html.textAreaElement Js.t}

type type_ = Text | Password | Textarea of {rows: int}
type font = Normal | Monospace

let prepare (type value)
  ~type_
  ?(font = Normal)
  ~label
  ?(placeholder = "")
  ~serialise
  ~validate
  ?(oninput = fun _ -> ())
  ?template
  ()
  : (value, string) Component.s
= (module struct
  let label = label

  type nonrec value = value
  type state = string [@@deriving yojson]

  let empty = ""
  let from_initial_text = Fun.id
  let value_to_string = lwt % serialise
  let value_to_state = lwt % serialise

  type t = {
    state: string S.t;
    signal: (value, string) result S.t;
    set: string -> unit;
    html: html;
  }

  let state i = i.state

  let signal i = i.signal

  let focus i =
    match i.html with
    | Text {input_dom; _} ->
      input_dom##focus;
      let length = String.length (Js.to_string input_dom##.value) in
      input_dom##.selectionStart := length;
      input_dom##.selectionEnd := length
    | Textarea {textarea_dom; _} -> textarea_dom##focus

  let trigger = focus

  let set i x = i.set <$> value_to_state x

  let clear i = lwt @@ i.set ""

  let initialise initial_value =
    let (state, set_immediately) = S.create initial_value in
    let set_delayed = S.delayed_setter 0.30 set_immediately in
    let signal = S.bind state validate in
    let html : html =
      match type_ with
      | Text | Password ->
        let input =
          input
            ()
            ~a: [
              a_input_type (match type_ with Text -> `Text | Password -> `Password | _ -> assert false);
              a_placeholder placeholder;
              R.a_class (
                S.l2
                  (@)
                  (
                    S.const @@
                    (match font with Normal -> [] | Monospace -> ["font-monospace"]) @ ["form-control"]
                  )
                  (Component.case_errored ~no: ["is-valid"] ~yes: (const ["is-invalid"]) signal)
              );
              (* monospace font looks huge by default so we reduce it a tad *)
              a_style (match font with Normal -> "" | Monospace -> "font-size: 0.9rem;");
              a_oninput (fun event ->
                (
                  Js.Opt.iter event##.target @@ fun elt ->
                  Js.Opt.iter (Dom_html.CoerceTo.input elt) @@ fun input ->
                  let input = Js.to_string input##.value in
                  set_delayed input;
                  oninput input
                );
                false
              );
              a_value initial_value;
            ]
        in
        Text {input; input_dom = To_dom.of_input input}
      | Textarea {rows} ->
        let textarea =
          textarea
            ~a: [
              a_rows rows;
              a_placeholder placeholder;
              R.a_class (
                S.l2
                  (@)
                  (
                    S.const @@
                    (match font with Normal -> [] | Monospace -> ["font-monospace"]) @
                      ["form-control"]
                  )
                  (Component.case_errored ~no: ["is-valid"] ~yes: (const ["is-invalid"]) signal)
              );
              (* monospace font looks huge by default so we reduce it a tad *)
              a_style (match font with Normal -> "" | Monospace -> "font-size: 0.9rem;");
              a_oninput (fun event ->
                (
                  Js.Opt.iter event##.target @@ fun elt ->
                  Js.Opt.iter (Dom_html.CoerceTo.textarea elt) @@ fun input ->
                  let input = Js.to_string input##.value in
                  set_delayed input;
                  oninput input
                );
                false
              );
            ]
            (txt initial_value)
        in
        Textarea {textarea; textarea_dom = To_dom.of_textarea textarea}
    in
    let set x =
      set_immediately x;
      match html with
      | Text {input_dom; _} -> input_dom##.value := Js.string x
      | Textarea {textarea_dom; _} -> textarea_dom##.value := Js.string x
    in
    lwt {state; signal; set; html}

  let inner_html i =
    match i.html with
    | Text {input; _} -> input
    | Textarea {textarea; _} -> textarea

  let actions i =
    S.flip_map i.state @@ function
      | "" ->
        (
          match template with
          | None -> []
          | Some template ->
            [
              Button.make
                ~classes: ["btn-info"]
                ~icon: (Action Magic)
                ~tooltip: "Fill the content of this input with the default template."
                ~onclick: (fun _ -> i.set template; lwt_unit)
                ();
            ]
        )
      | _ ->
        [
          Button.make
            ~classes: ["btn-warning"]
            ~icon: (Action Clear)
            ~tooltip: "Clear the content of this input. It cannot be recovered."
            ~onclick: (fun _ -> i.set ""; lwt_unit)
            ();
        ]
end)

let make ~type_ ?font ~label ?placeholder ~serialise ~validate ?oninput ?template initial_value =
  Component.initialise (prepare ~type_ ?font ~label ?placeholder ~serialise ~validate ?oninput ?template ()) initial_value

let inactive ~label value =
  Component.html_fake ~label @@
    input () ~a: [a_input_type `Text; a_value value; a_class ["form-control"]; a_disabled ()]

let prepare_option
    ~type_
    ?font
    ~label
    ?placeholder
    ~serialise
    ~validate
    ?oninput
    ?template
    ()
  =
  prepare
    ~type_
    ?font
    ~label: (label ^ " (optional)")
    ?placeholder
    ~serialise: (Option.fold ~none: "" ~some: (NEString.to_string % serialise))
    ~validate: (Option.fold ~none: (S.const @@ ok None) ~some: (S.map (Result.map Option.some) % validate) % NEString.of_string)
    ?oninput
    ?template
    ()

let make_option ~type_ ?font ~label ?placeholder ~serialise ~validate ?oninput ?template initial_value =
  Component.initialise (prepare_option ~type_ ?font ~label ?placeholder ~serialise ~validate ?oninput ?template ()) initial_value

let prepare_non_empty ~type_ ?font ~label ?placeholder ?oninput ?template () =
  prepare
    ~type_
    ?font
    ~label
    ?placeholder
    ~serialise: NEString.to_string
    ~validate: (S.const % Option.to_result ~none: "This field cannot be empty." % NEString.of_string)
    ?oninput
    ?template
    ()

let make_non_empty ~type_ ?font ~label ?placeholder ?oninput ?template initial_value =
  Component.initialise (prepare_non_empty ~type_ ?font ~label ?placeholder ?oninput ?template ()) initial_value
