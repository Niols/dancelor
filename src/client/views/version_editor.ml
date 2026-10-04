open Nes
open Dancelor_common
module Model = Model_builder.Core
open Components
open Html
open Utils

let structure =
  Input.prepare
    ~type_: Text
    ~placeholder: "eg. AABB or ABAB"
    ~serialise: (NEString.to_string % Model.Version.Structure.to_string)
    ~validate: (
      S.const % Option.to_result ~none: "not a valid structure" %
        (fun s -> Option.bind (NEString.of_string s) Model.Version.Structure.of_string
        )
    )

let content_monolithic () =
  let open Bundle in
  group
    ~label: "Monolithic"
    ~wrap: (fun (bars, (structure, (lilypond, ()))) ->
      {Model_builder.Core.Version.Content.bars; structure; lilypond}
    )
    ~unwrap: (fun {Model_builder.Core.Version.Content.bars; structure; lilypond} ->
      (bars, (structure, (lilypond, ())))
    )
    (
      Input.prepare
        ~type_: Text
        ~label: "Number of bars"
        ~placeholder: "eg. 32 or 48"
        ~serialise: string_of_int
        ~validate: (
          S.const %
            Option.to_result ~none: "The number of bars has to be an integer." %
            int_of_string_opt
        )
        () ^::
      structure ~label: "Structure" () ^::
      Input.prepare
        ~type_: (Textarea {rows = 20})
        ~font: Monospace
        ~label: "Full LilyPond"
        ~placeholder: "\\relative f' <<\n  {\n    \\clef treble\n    \\key d \\minor\n    \\time 4/4\n\n    ...\n  }\n\n  \\new ChordNames {\n    \\chordmode {\n    ...\n    }\n  }\n>>"
        ~serialise: id
        ~validate: (S.const % Result.of_string_nonempty ~empty: "Cannot be empty.")
        ~template: "\\relative f' <<\n  {\n    \\clef treble\n    \\key d \\major\n    \\time 4/4\n\n    %% add tune here\n  }\n\n  \\new ChordNames {\n    \\chordmode {\n      %% add chords here\n    }\n  }\n>>"
        () ^::
      nil
    )

let content_destructured () =
  let open Bundle in
  group
    ~label: "Destructured"
    ~wrap: (fun (default_structure, (as_2_4, (parts, (transitions, ())))) ->
      {Model_builder.Core.Version.Content.default_structure; as_2_4; parts; transitions}
    )
    ~unwrap: (fun {Model_builder.Core.Version.Content.default_structure; as_2_4; parts; transitions} ->
      (default_structure, (as_2_4, (parts, (transitions, ()))))
    )
    (
      structure ~label: "Default structure" () ^::
      (
        let open Plus.Tuple_elt in
        Plus.prepare
          ~label: "How this reel should be written"
          ~cast: (function
            | Zero() -> false
            | Succ Zero() -> true
            | _ -> assert false (* types guarantee this is not reachable *)
          )
          ~uncast: (function
            | false -> Zero ()
            | true -> one ()
          )
          ~selected_when_empty: 0
          (
            let open Plus.Bundle in
            Nil.prepare ~label: "As 2/2" () ^::
            Nil.prepare ~label: "As 2/4" () ^::
            nil
          )
      ) ^::
      (
        Star.prepare_non_empty
          ~label: "Parts"
          ~make_header: (fun n -> div [txtf "Part %c" @@ Model.Version.Part_name.(to_char % of_int) n])
          (
            group
              ~label: "Part"
              ~wrap: (fun (melody, (chords, ())) -> {Model_builder.Core.Version.Voices.melody; chords})
              ~unwrap: (fun {Model_builder.Core.Version.Voices.melody; chords} -> (melody, (chords, ())))
              (
                cons
                  ~stacking: No_label
                  (
                    Input.prepare
                      ~type_: (Textarea {rows = 11})
                      ~font: Monospace
                      ~label: "Melody"
                      ~serialise: id
                      ~validate: (S.const % ok)
                      ~placeholder: "\\partial 4 a4 |\nd,4 fis8 a b4 a |\nb8 a b cis d4 d8 cis |\nb4 d8 fis b a g fis |\ne d cis b a g fis e |\n\\break\n\nd4 fis8 a b4 a |\nb8 a b cis d4 d8 cis |\nb4 d8 fis b a g fis |\ne d e fis d4"
                      ()
                  )
                  (
                    cons
                      ~stacking: No_label
                      (
                        Input.prepare
                          ~type_: (Textarea {rows = 2})
                          ~font: Monospace
                          ~label: "Chords"
                          ~serialise: id
                          ~validate: (S.const % ok)
                          ~placeholder: "s4 | d2 g | a d | b:m e:m | a2 a:7 |\nd2 g | a d | b:m e:m | a2:7 d4"
                          ()
                      )
                      nil
                  )
              )
          )
      ) ^::
      (
        Star.prepare
          ~label: "Transitions"
          ~make_header: (fun n -> div [txtf "Transition #%d" (n + 1)])
          (
            pair
              ~label: "Transition"
              ~stacking: No_label
              ~wrap: (fun ((from_parts, to_parts), voices) ->
                (from_parts, to_parts, voices)
              )
              ~unwrap: (fun (from_parts, to_parts, voices) ->
                ((from_parts, to_parts), voices)
              )
              (
                pair
                  ~stacking: Input_group
                  ~wrap: Fun.id
                  ~unwrap: Fun.id
                  (
                    Input.prepare
                      ~type_: Text
                      ~serialise: Model.Version.Part_name.opens_to_string
                      ~validate: (S.const % Option.to_result ~none: "Not a valid list of part names" % Model.Version.Part_name.opens_of_string)
                      ~label: "from"
                      ~placeholder: "eg. “A”, “B” or “start”"
                      ()
                  )
                  (
                    Input.prepare
                      ~type_: Text
                      ~serialise: Model.Version.Part_name.opens_to_string
                      ~validate: (S.const % Option.to_result ~none: "Not a valid list of part names" % Model.Version.Part_name.opens_of_string)
                      ~label: "to"
                      ~placeholder: "eg. “A”, “B” or “end”"
                      ()
                  )
              )
              (
                pair
                  ~stacking: No_label
                  ~wrap: (fun (melody, chords) ->
                    {Model_builder.Core.Version.Voices.melody; chords}
                  )
                  ~unwrap: (fun {Model_builder.Core.Version.Voices.melody; chords} ->
                    (melody, chords)
                  )
                  (
                    Input.prepare
                      ~type_: (Textarea {rows = 1})
                      ~font: Monospace
                      ~label: "Melody"
                      ~serialise: id
                      ~validate: (S.const % ok)
                      ~placeholder: "\\relative f' { e8 d e f d4 }"
                      ()
                  )
                  (
                    Input.prepare
                      ~type_: (Textarea {rows = 1})
                      ~font: Monospace
                      ~label: "Chords"
                      ~serialise: id
                      ~validate: (S.const % ok)
                      ~placeholder: "a2:7 d4"
                      ()
                  )
              )
          )
      ) ^::
      nil
    )

let content () =
  let open Plus.Tuple_elt in
  Plus.prepare
    ~label: "Content"
    ~cast: (function
      | Zero() -> Model.Version.Content.No_content
      | Succ Zero destructured -> Model.Version.Content.Destructured destructured
      | Succ Succ Zero monolithic -> Model.Version.Content.Monolithic monolithic
      | _ -> assert false (* types guarantee this is not reachable *)
    )
    ~uncast: (function
      | Model.Version.Content.No_content -> Zero ()
      | Model.Version.Content.Destructured destructured -> one destructured
      | Model.Version.Content.Monolithic monolithic -> two monolithic
    )
    ~selected_when_empty: 0
    (
      let open Plus.Bundle in
      Nil.prepare ~label: "No content" () ^::
      content_destructured () ^::
      content_monolithic () ^::
      nil
    )

let editor =
  let open Bundle in
  group
    ~wrap: (fun (tune, (key, (arrangers, (remark, (sources, (disambiguation, (content, ()))))))) ->
      {Version_form.tune; key; arrangers; remark; sources; disambiguation; content}
    )
    ~unwrap: (fun {Version_form.tune; key; arrangers; remark; sources; disambiguation; content} ->
      (tune, (key, (arrangers, (remark, (sources, (disambiguation, (content, ())))))))
    )
    ~check: Version_form.equal
    (
      Selector.prepare
        ~make_descr: (lwt % Tune_row.name)
        ~make_result: (Any_result.make_tune_result ?in_search: None)
        ~label: "Tune"
        ~model_name: "tune"
        ~create_dialog_content: Tune_editor.create_row
        ~search: Api.tune_search
        ~id_to_yojson: Id.to_yojson'
        ~id_of_yojson: Id.of_yojson'
        ~serialise: Tune_row.id
        ~unserialise: (Api.call_or_option @@ Tune Get_row)
        () ^::
      Input.prepare
        ~type_: Text
        ~label: "Key"
        ~placeholder: "eg. A or F#m"
        ~serialise: Music.Key.to_string
        ~validate: (
          S.const %
            Option.to_result ~none: "Enter a valid key, eg. A of F#m." %
            Music.Key.of_string_opt
        )
        () ^::
      Star.prepare
        ~label: "Arrangers"
        (
          Selector.prepare
            ~make_descr: (lwt % Person_row.name)
            ~make_result: (Any_result.make_person_result ?in_search: None)
            ~results_when_no_search: (Option.to_list <$> Environment.person)
            ~label: "Arranger"
            ~model_name: "person"
            ~create_dialog_content: Person_editor.create_row
            ~search: Api.person_search
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
            ~serialise: Person_row.id
            ~unserialise: (Api.call_or_option @@ Person Get_row)
            ()
        ) ^::
      Input.prepare_option
        ~type_: Text
        ~label: "Remark"
        ~placeholder: "Any additional information that doesn't fit in the other fields."
        ~serialise: Fun.id
        ~validate: (S.const % ok)
        () ^::
      Star.prepare
        ~label: "Sources"
        (
          group
            ~label: "Source"
            ~wrap: (fun (source, (structure, (details, ()))) -> {Version_form.source; structure; details})
            ~unwrap: (fun {Version_form.source; structure; details} -> (source, (structure, (details, ()))))
            (
              cons
                ~stacking: No_label
                (
                  Selector.prepare
                    ~make_descr: (lwt % Source_row.name)
                    ~make_result: (Any_result.make_source_result ?in_search: None)
                    ~label: "Source"
                    ~model_name: "source"
                    ~create_dialog_content: Source_editor.create_row
                    ~search: Api.source_search
                    ~id_to_yojson: Id.to_yojson'
                    ~id_of_yojson: Id.of_yojson'
                    ~serialise: Source_row.id
                    ~unserialise: (Api.call_or_option @@ Source Get_row)
                    ()
                )
                (
                  cons
                    ~stacking: No_label
                    (structure ~label: "Structure in that particular source" ())
                    (
                      cons
                        ~stacking: No_label
                        (
                          Input.prepare_option
                            ~type_: Text
                            ~label: "FIXME"
                            ~placeholder: "eg. “for The Eightsome Reel” or “as a 2/4 reel”"
                            ~serialise: id
                            ~validate: (S.const % ok)
                            ()
                        )
                        nil
                    )
                )
            )
        ) ^::
      Input.prepare_option
        ~type_: Text
        ~label: "Disambiguation"
        ~placeholder: "If there are multiple versions with the same name, this field must be used to distinguish them."
        ~serialise: Fun.id
        ~validate: (S.const % ok)
        () ^::
      content () ^::
      nil
    )

let preview version =
  let {Version_form.tune; content; _} = version in
  match content with
  | No_content -> lwt_true
  | _ ->
    let slug = NesSlug.of_string tune.name in
    Option.fold ~none: false ~some: (const true)
    <$> Page.open_dialog @@ fun return ->
      Page.make'
        ~title: (lwt "Preview")
        [Components.Version_snippets.make_preview ~show_logs: true slug version]
        ~buttons: [
          Button.cancel' ~return ();
          Button.save ~onclick: (fun () -> return (Some ()); lwt_unit) ();
        ]

let submit mode version =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Version Update) id version;%lwt lwt id
    | _ -> Api.call_exn (Version Create) version
  in
  lwt {With_id.id; form = version}

let unsubmit = lwt % With_id.form

let prepare () =
  Editor.prepare
    ~key: "version"
    ~icon: (Model Version)
    editor
    ~href: (Endpoints.Page.href_version % With_id.id)
    ~format: (Formatters.Version.name ~link: true % With_id.map Version_form.to_name)
    ~submit
    ~unsubmit
    ~preview

let create_gen mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  let editor = prepare () in
  let mode =
    match mode with
    | `With_mode mode -> mode
    | `Make_mode_from_tune_id tune_id ->
      (* FIXME: ugly hacking of editor state; I wish we had a better mechanism for this *)
      let (_, rest_of_state) = Editor.empty editor in
      Editor.Create (Some tune_id, rest_of_state)
  in
  Editor.page =<< Editor.initialise editor mode

(* Needs to be exposed for other editors. *)
let create mode = create_gen (`With_mode mode)

let create_row (mode : (Version_row.t, 'a) Editor.mode) =
  let%lwt (mode : ((Version_id.t, Version_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map Version_form.to_row)
        )
    | Edit {Version_row.id; _} ->
      let%lwt form = Api.call_exn (Version Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add = function
  | None -> create Create_with_local_storage
  | Some tune_id -> create_gen (`Make_mode_from_tune_id tune_id)

let edit id =
  let%lwt form = Api.call_exn (Version Get_form) id in
  create @@ Edit {With_id.id; form}
