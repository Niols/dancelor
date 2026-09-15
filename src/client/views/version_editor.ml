open Nes
open Dancelor_common
open Model_new
open Search_new
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
  Cpair.prepare
    ~label: "Monolithic"
    (
      Cpair.prepare
        ~label: "FIXME"
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
            ()
        )
        (structure ~label: "Structure" ())
    )
    (
      Input.prepare
        ~type_: (Textarea {rows = 20})
        ~font: Monospace
        ~label: "Full LilyPond"
        ~placeholder: "\\relative f' <<\n  {\n    \\clef treble\n    \\key d \\minor\n    \\time 4/4\n\n    ...\n  }\n\n  \\new ChordNames {\n    \\chordmode {\n    ...\n    }\n  }\n>>"
        ~serialise: id
        ~validate: (S.const % Result.of_string_nonempty ~empty: "Cannot be empty.")
        ~template: "\\relative f' <<\n  {\n    \\clef treble\n    \\key d \\major\n    \\time 4/4\n\n    %% add tune here\n  }\n\n  \\new ChordNames {\n    \\chordmode {\n      %% add chords here\n    }\n  }\n>>"
        ()
    )

let content_destructured () =
  Cpair.prepare
    ~label: "Destructured"
    (structure ~label: "Default structure" ())
    (
      Cpair.prepare
        ~label: "FIXME"
        (
          let open Plus.Tuple_elt in
          Plus.prepare
            ~label: "As 2/4"
            ~cast: (function
              | Zero() -> `As_2_2
              | Succ Zero() -> `As_2_4
              | _ -> assert false (* types guarantee this is not reachable *)
            )
            ~uncast: (function
              | `As_2_2 -> Zero ()
              | `As_2_4 -> one ()
            )
            ~selected_when_empty: 0
            (
              let open Plus.Bundle in
              Nil.prepare ~label: "As 2/2" () ^::
              Nil.prepare ~label: "As 2/4" () ^::
              nil
            )
        )
        (
          Cpair.prepare
            ~label: "FIXME"
            (
              Star.prepare_non_empty
                ~label: "Parts"
                ~make_header: (fun n -> div [txtf "Part %c" @@ Model.Version.Part_name.(to_char % of_int) n])
                (
                  Cpair.prepare
                    ~label: "Part"
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
                      Input.prepare
                        ~type_: (Textarea {rows = 2})
                        ~font: Monospace
                        ~label: "Chords"
                        ~serialise: id
                        ~validate: (S.const % ok)
                        ~placeholder: "s4 | d2 g | a d | b:m e:m | a2 a:7 |\nd2 g | a d | b:m e:m | a2:7 d4"
                        ()
                    )
                )
            )
            (
              Star.prepare
                ~label: "Transitions"
                ~make_header: (fun n -> div [txtf "Transition #%d" (n + 1)])
                (
                  Cpair.prepare
                    ~label: "Transition"
                    (
                      Cpair.prepare
                        ~label: "Transition parts"
                        ~input_group: true
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
                      Cpair.prepare
                        ~label: "Transition content"
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
            )
        )
    )

let content () =
  let open Plus.Tuple_elt in
  Plus.prepare
    ~label: "Content"
    ~cast: (function
      | Zero() -> Model.Version.Content.No_content
      | Succ Zero (default_structure, (as_2_4, (parts, transitions))) ->
        let wrap_part (melody, chords) = {Model.Version.Voices.melody; chords} in
        Model.Version.Content.Destructured
          {
            default_structure;
            as_2_4 = (match as_2_4 with `As_2_2 -> false | `As_2_4 -> true);
            parts = NEList.map wrap_part parts;
            transitions = List.map (fun ((from, to_), part) -> (from, to_, wrap_part part)) transitions;
          }
      | Succ Succ Zero ((bars, structure), lilypond) ->
        Model.Version.Content.Monolithic {bars; structure; lilypond}
      | _ -> assert false (* types guarantee this is not reachable *)
    )
    ~uncast: (function
      | Model.Version.Content.No_content -> Zero ()
      | Model.Version.Content.Destructured {default_structure; as_2_4; parts; transitions} ->
        let unwrap_part Model.Version.Voices.{melody; chords} = (melody, chords) in
        one (
          default_structure,
          (
            (if as_2_4 then `As_2_4 else `As_2_2),
            (
              NEList.map unwrap_part parts,
              List.map (fun (from, to_, part) -> ((from, to_), unwrap_part part)) transitions
            )
          )
        )
      | Model.Version.Content.Monolithic {bars; structure; lilypond} -> two ((bars, structure), lilypond)
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
  let open Editor in
  Selector.prepare
    ~make_descr: (lwt % Tune_row.name)
    ~make_result: (Any_result_new.make_tune_result ?in_search: None)
    ~label: "Tune"
    ~model_name: "tune"
    ~create_dialog_content: Tune_editor.create_row
    ~search: (fun slice query ->
      match Tune_query.parse query with
      | Error msg -> lwt_error msg
      | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ Tune Search) slice query
    )
    ~id_to_yojson: Entry.Id.to_yojson'
    ~id_of_yojson: Entry.Id.of_yojson'
    ~serialise: Tune_row.id
    ~unserialise: (madge_call_or_option @@ Tune Get_row)
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
        ~make_result: (Any_result_new.make_person_result ?in_search: None)
        ~results_when_no_search: (Option.to_list <$> Environment.person_row)
        ~label: "Arranger"
        ~model_name: "person"
        ~create_dialog_content: Person_editor.create_row
        ~search: (fun slice query ->
          match Person_query.parse query with
          | Error msg -> lwt_error msg
          | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ Person Search) slice query
        )
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: Person_row.id
        ~unserialise: (madge_call_or_option @@ Person Get_row)
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
      Cpair.prepare
        ~label: "Source"
        (
          Selector.prepare
            ~make_descr: (lwt % Source_row.name)
            ~make_result: (Any_result_new.make_source_result ?in_search: None)
            ~label: "Source"
            ~model_name: "source"
            ~create_dialog_content: Source_editor.create_row
            ~search: (fun slice query ->
              match Source_query.parse query with
              | Error msg -> lwt_error msg
              | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ Source Search) slice query
            )
            ~id_to_yojson: Entry.Id.to_yojson'
            ~id_of_yojson: Entry.Id.of_yojson'
            ~serialise: Source_row.id
            ~unserialise: (madge_call_or_option @@ Source Get_row)
            ()
        )
        (
          Cpair.prepare
            ~label: "FIXME"
            (structure ~label: "Structure in that particular source" ())
            (
              Input.prepare_option
                ~type_: Text
                ~label: "FIXME"
                ~placeholder: "eg. “for The Eightsome Reel” or “as a 2/4 reel”"
                ~serialise: id
                ~validate: (S.const % ok)
                ()
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

let assemble (tune, (key, (arrangers, (remark, (sources, (disambiguation, (content, ()))))))) =
  let tune = Tune_row.id tune in
  let arrangers = List.map Person_row.id arrangers in
  let sources = List.map (fun (source, (structure, details)) -> Model.Version.{source = Source_row.id source; structure; details}) sources in
  Model.Version.make ~tune ~key ~arrangers ~remark ~sources ~disambiguation ~content ()

let preview version =
  match Model.Version.content version with
  | No_content -> lwt_true
  | _ ->
    let%lwt slug = Model.Version.slug version in
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
    | Editor.Edit prev_version ->
      Madge_client.call_exn Endpoints.Api.(route @@ Version Update) (Entry.id prev_version) version;%lwt
      lwt (Entry.id prev_version)
    | _ -> Madge_client.call_exn Endpoints.Api.(route @@ Version Create) version
  in
  Madge_client.call_exn Endpoints.Api.(route @@ Version Get) id

let unsubmit version =
  (* NOTE: The API erases the LilyPond from versions, so we need to pull the
     full content ourselves and re-insert it in the version. *)
  let%lwt content = Madge_client.call_exn Endpoints.Api.(route @@ Version Content) (Entry.id version) in
  let content =
    match content with
    | Endpoints.Version.Protected -> assert false
    | Endpoints.Version.Granted {payload; _} -> payload
  in
  lwt @@ Model.Version.set_content content (Entry.value version)

let disassemble version =
  let%lwt tune = Madge_client.call_exn Endpoints.Api.(route @@ Tune Get_row) (Model.Version.tune_id version) in
  let key = Model.Version.key version in
  let%lwt arrangers = Lwt_list.map_p (Madge_client.call_exn Endpoints.Api.(route @@ Person Get_row)) (Model.Version.arrangers version) in
  let remark = Model.Version.remark version in
  let%lwt sources =
    Lwt_list.map_p
      (fun Model.Version.{source; structure; details} ->
        let%lwt source = Madge_client.call_exn Endpoints.Api.(route @@ Source Get_row) source in
        lwt (source, (structure, details))
      )
      (Model.Version.sources version)
  in
  let disambiguation = Model.Version.disambiguation version in
  let content = Model.Version.content version in
  lwt (tune, (key, (arrangers, (remark, (sources, (disambiguation, (content, ())))))))

let prepare () =
  Editor.prepare
    ~key: "version"
    ~icon: (Model Version)
    editor
    ~href: (fun version -> Endpoints.Page.href_version (Entry.id version))
    ~format: (Formatters.Version.name' ~link: true)
    ~assemble
    ~submit
    ~unsubmit
    ~disassemble
    ~preview
    ~check_product: Model.Version.equal

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

let to_row (version : Model.Version.entry) : Version_row.t Lwt.t =
  let content_to_content = function
    | Model.Version.Content.No_content -> Version_row.No_content
    | Destructured _ -> Destructured
    | Monolithic {bars; structure; _} -> Monolithic {bars; structure}
  in
  let%lwt tune = Tune_editor.to_row =<< Model.Version.tune' version in
  let%lwt sources = Lwt_list.map_s (Option.get <%> Model.Source.get % Model.Version.source_source) @@ Model.Version.sources' version in
  let sources = List.map Source_editor.to_short_name sources in
  let%lwt arrangers = Lwt_list.map_s (Person_editor.to_name % Option.get <%> Model.Person.get) (Model.Version.arrangers' version) in
  lwt {
    Version_row.id = Entry.id version;
    tune;
    sources;
    disambiguation = Option.map NEString.to_string @@ Model.Version.disambiguation' version;
    arrangers;
    content = content_to_content @@ Model.Version.content' version;
  }

let create_row (mode : (Version_row.t, 'a) Editor.mode) =
  let%lwt (mode : (Model.Version.entry, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (fun version -> callback =<< to_row version)
        )
    | Edit result ->
      let%lwt result = Option.get <$> Model.Version.get (Version_row.id result) in
      lwt @@ Editor.Edit result
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add = function
  | None -> create Create_with_local_storage
  | Some tune_id -> create_gen (`Make_mode_from_tune_id tune_id)

let edit id =
  let%lwt version = Option.get <$> Model.Version.get id in
  create (Edit version)
