(* FIXME: Selectors should only expose ids and not entries, that sounds much
   easier to manipulate; then it's just a matter of grabbing the entry so as to
   show it nicely, but the selector doesn't really need to know all this. *)

open Js_of_ocaml
open Nes
open Utils
open Html

let prepare_gen (type id)(type model)(type model_validated)
  ~label
  ~search
  ~id_to_yojson
  ~id_of_yojson
  ~serialise
  ~unserialise
  ~make_descr
  ~(make_result :
    ?classes: string list ->
    ?onclick: (unit -> unit Lwt.t) ->
    ?prefix: Html_types.td Html.elt list ->
    ?suffix: Html_types.td Html.elt list ->
    model ->
    Html_types.tr Html.elt
  )
  ?(make_more_results = (
    const (S.const [])
    : model ->
      Html_types.tr Html.elt list S.t
  ))
  ?(results_when_no_search = lwt_nil)
  ~model_name
  ?(create_dialog_content : ((model, 'any) Editor.mode -> Page.t Lwt.t) option)
  ~(validate : model option -> (model_validated, string) Result.t)
  ~(unvalidate : model_validated -> model option)
  ()
  : (model_validated, id option) Component.s
= (module struct
  let label = label

  type value = model_validated

  type state = id option [@@deriving yojson]

  let empty = None
  let from_initial_text _ = None

  let value_to_string = Option.fold ~none: (lwt "<invalid model>") ~some: make_descr % unvalidate

  let value_to_state = lwt % Option.map serialise % unvalidate

  type t = {
    signal: model option S.t;
    set: model option -> unit;
    (* quick_search: model Entry.t Search.Quick.t; *)
    inner_html: Html_types.div_content_fun elt;
    select_button_dom: Dom_html.buttonElement Js.t;
  }

  let state s = S.map (flip Option.bind (some % serialise)) s.signal (* FIXME: can we simplify? *)

  let signal i = S.map validate i.signal

  let inner_html s = s.inner_html

  let actions s =
    S.flip_map s.signal @@ function
      | None -> []
      | Some _ ->
        [
          Button.make
            ~classes: ["btn-warning"]
            ~icon: (Action Clear)
            ~tooltip: (spf "Clear the selected %s. It cannot be recovered." model_name)
            ~onclick: (fun _ -> s.set None; lwt_unit)
            ();
        ]

  let focus s = s.select_button_dom##focus
  let trigger s = s.select_button_dom##click

  let set _ _ = assert false

  let clear s = lwt @@ s.set None

  let initialise initial_value =
    let (signal, set) = S.create None in
    let quick_search = Search.Quick.make ~search () in
    Lwt.async (fun () ->
      let%lwt initial_value =
        match initial_value with
        | None -> lwt_none
        | Some initial_value -> unserialise initial_value
      in
      set initial_value;
      lwt_unit
    );
    let select_model () =
      let%lwt results_when_no_search = results_when_no_search in
      let%lwt quick_search_result =
        Page.open_dialog @@ fun quick_search_return ->
        Search.Quick.render
          quick_search
          ~return: quick_search_return
          ~dialog_title: (lwt label)
          ~make_result: (fun ?in_search: _ result ->
            make_result
              ~onclick: (fun () -> lwt @@ quick_search_return (Some result))
              result
          )
          ~results_when_no_search
          ~dialog_buttons: (
            match create_dialog_content with
            | None -> []
            | Some create_dialog_content ->
              [
                Button.make
                  ~label: ("Create new " ^ model_name)
                  ~label_processing: ("Creating new " ^ model_name ^ "...")
                  ~icon: (Action Add)
                  ~classes: ["btn-primary"]
                  ~onclick: (fun () ->
                    quick_search_return
                    <$> Page.open_dialog' @@ fun sub_dialog_return ->
                      create_dialog_content (
                        Editor.Quick_create (
                          S.value (Search.Quick.text quick_search),
                          lwt % sub_dialog_return
                        )
                      )
                  )
                  ();
              ]
          )
      in
      Search_bar.clear @@ Search.Quick.search_bar quick_search;
      Option.iter (set % some) quick_search_result;
      lwt_unit
    in
    let select_button =
      Button.make
        ~label: ("Select a " ^ model_name)
        ~label_processing: ("Selecting a " ^ model_name ^ "...")
        ~classes: ["text-secondary"; "btn-outline-light"; "w-100"; "text-start"]
        ~onclick: select_model
        ()
    in
    let select_button_dom = To_dom.of_button select_button in
    let inner_html =
      R.div (
        S.flip_map signal @@ function
          | None ->
            [
              div
                ~a: [a_class ["btn-group"; "w-100"]]
                [
                  Button.make_icon (Action Search) ~classes: ["btn-light"];
                  select_button;
                ];
            ]
          | Some model ->
            [
              div ~a: [a_class ["rounded-2"; "border"; "w-100"; "px-2"; "py-1"]] [
                tablex
                  ~a: [a_class ["table"; "table-borderless"; "table-sm"; "m-0"]]
                  [tbody [make_result model]];
              ];
              div ~a: [a_class ["row"; "m-0"; "overflow-hidden"]] [
                tablex
                  ~a: [a_class ["table"; "table-borderless"; "table-sm"; "m-0"; "col"]]
                  [R.tbody (make_more_results model)];
              ]
            ]
      )
    in
    lwt {signal; set; inner_html; select_button_dom}
end)

let prepare
    ~label
    ~search
    ~id_to_yojson
    ~id_of_yojson
    ~serialise
    ~unserialise
    ~make_descr
    ~make_result
    ?make_more_results
    ?results_when_no_search
    ~model_name
    ?create_dialog_content
    ()
    : ('model, 'id option) Component.s
  =
  prepare_gen
    ~label
    ~id_to_yojson
    ~id_of_yojson
    ~search
    ~serialise
    ~unserialise
    ~make_descr
    ~make_result
    ?make_more_results
    ?results_when_no_search
    ~model_name
    ?create_dialog_content
    ~validate: (Option.to_result ~none: "You must select an element.")
    ~unvalidate: Option.some
    ()

let make
    ~label
    ~search
    ~id_to_yojson
    ~id_of_yojson
    ~serialise
    ~unserialise
    ~make_descr
    ~make_result
    ?make_more_results
    ?results_when_no_search
    ~model_name
    ?create_dialog_content
    initial_value
  =
  Component.initialise
    (
      prepare
        ~label
        ~id_to_yojson
        ~id_of_yojson
        ~search
        ~serialise
        ~unserialise
        ~make_descr
        ~make_result
        ?make_more_results
        ?results_when_no_search
        ~model_name
        ?create_dialog_content
        ()
    )
    initial_value
