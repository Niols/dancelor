open Nes
open Html
open Utils

let prepare (type comp_value)(type comp_state)(type params)(type params_state)
  ((module C): (comp_value, comp_state) Component.s)
  (editor : (params, params, params_state) Editor.s)
  : (comp_value * params, comp_state * params_state) Component.s
= (module struct

  type value = C.value * params

  let params_state_of_yojson = Editor.state_of_yojson editor
  let params_state_to_yojson = Editor.state_to_yojson editor

  type state = C.state * params_state [@@deriving yojson]

  let empty = (C.empty, Editor.empty editor)

  let from_initial_text (text : string) =
    (C.from_initial_text text, Editor.empty editor)

  let value_to_string (value, _params) =
    let%lwt result = C.value_to_string value in
    lwt @@ result ^ " (parameterised)"

  let value_to_state (value, params) =
    let%lwt value = C.value_to_state value in
    let%lwt params = Editor.result_to_state editor params in
    lwt (value, params)

  type t = {
    comp: C.t;
    editor: (params, params, params_state) Editor.t;
  }

  let initialise (initial_value, initial_params) =
    let%lwt comp = C.initialise initial_value in
    let%lwt editor = Editor.initialise editor @@ Editor.Quick_edit initial_params in
    lwt {comp; editor}

  let signal p =
    RS.bind (C.signal p.comp) @@ fun value ->
    RS.bind (Editor.signal p.editor) @@ fun params ->
    S.const (Ok (value, params))

  let state p =
    S.bind (C.state p.comp) @@ fun state ->
    S.bind (Editor.state p.editor) @@ fun params_state ->
    S.const (state, params_state)

  let set p (value, params) =
    C.set p.comp value;%lwt
    Editor.set p.editor params

  let clear p =
    C.clear p.comp;%lwt
    Editor.clear p.editor

  let label = C.label
  let inner_html p = C.inner_html p.comp
  let focus p = C.focus p.comp
  let trigger p = C.trigger p.comp

  let actions p =
    S.l2
      (@)
      (
        S.const [
          Button.make
            ~icon: (Action Parameterise)
            ~classes: ["btn-outline-secondary"]
            ~tooltip: ("Edit this " ^ Editor.(key % s) p.editor)
            ~onclick: (fun () ->
              let%lwt comp_descr =
                match S.value @@ C.signal p.comp with
                | Error _ -> lwt ""
                | Ok comp_value -> ((^) " for ") <$> C.value_to_string comp_value
              in
              ignore
              <$> Page.open_dialog' @@ fun return ->
                Editor.page
                  p.editor
                  ~title_suffix: comp_descr
                  ~after_save: (fun _ ->
                    Toast.open_ ~title: (spf "Set parameters%s" comp_descr) [
                      txtf
                        "Your parameters%s have been set. However, this will only \
                         take effect once save the whole editor for the change \
                         to be recorded."
                        comp_descr
                    ];
                    lwt @@ return ()
                  )
            )
            ()
        ]
      )
      (C.actions p.comp)
end)
