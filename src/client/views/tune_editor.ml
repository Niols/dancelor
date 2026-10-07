open Nes
open Dancelor_common
open Components
open Html
open Utils

let editor =
  let open Bundle in
  group
    ~wrap: (fun (names, (kind, (composers, (date, (dances, (remark, (scddb_id, ()))))))) ->
      {Tune_form.names; kind; composers; date; dances; remark; scddb_id}
    )
    ~unwrap: (fun {Tune_form.names; kind; composers; date; dances; remark; scddb_id} ->
      (names, (kind, (composers, (date, (dances, (remark, (scddb_id, ())))))))
    )
    ~check: Tune_form.equal
    (
      Star.prepare_non_empty
        ~label: "Names"
        (
          Input.prepare_non_empty
            ~label: "Name"
            ~type_: Text
            ~placeholder: "eg. The Cairdin O't"
            ()
        ) ^::
      Choices.prepare_radios
        ~label: "Kind"
        (
          List.map
            (fun kind ->
              Choices.choice ~value: kind [txt @@ Kind.Base.to_long_string ~capitalised: true kind]
            )
            Kind.Base.all
        ) ^::
      Star.prepare
        ~label: "Composers"
        (
          pair
            ~label: "Composer"
            ~stacking: No_label
            ~wrap: (fun (composer, details) -> {Tune_form.composer; details})
            ~unwrap: (fun {Tune_form.composer; details} -> (composer, details))
            (
              Selector.prepare
                ~make_descr: (lwt % Person_row.name)
                ~make_result: (Tables.person_row ?in_search: None)
                ~results_when_no_search: (Option.to_list <$> Environment.person)
                ~label: "Composer"
                ~model_name: "person"
                ~create_dialog_content: Person_editor.create_row
                ~search: Api.person_search
                ~id_to_yojson: Id.to_yojson'
                ~id_of_yojson: Id.of_yojson'
                ~serialise: Person_row.id
                ~unserialise: (Api.call_or_option @@ Person Get_row)
                ()
            )
            (
              Input.prepare_option
                ~type_: Text
                ~label: "Details"
                ~placeholder: "eg. “chords only”"
                ~serialise: id
                ~validate: (S.const % ok)
                ()
            )
        ) ^::
      Input.prepare
        ~type_: Text
        ~label: "Date of composing"
        ~placeholder: "eg. 2019 or 2012-03-14"
        ~serialise: (Option.fold ~none: "" ~some: Partial_date.to_string)
        ~validate: (
          S.const %
            Option.fold
              ~none: (Ok None)
              ~some: (Result.map some % Option.to_result ~none: "Enter a valid date, eg. 2019 or 2012-03-14" % Partial_date.from_string) %
            Option.of_string_nonempty
        )
        () ^::
      Star.prepare
        ~label: "Dances"
        (
          Selector.prepare
            ~search: Api.dance_search
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
            ~serialise: Dance_row.id
            ~unserialise: (Api.call_or_option @@ Dance Get_row)
            ~make_descr: (lwt % Dance_row.name)
            ~make_result: (Tables.dance_row ?in_search: None)
            ~label: "Dance"
            ~model_name: "dance"
            ~create_dialog_content: Dance_editor.create_row
            ()
        ) ^::
      Input.prepare_option
        ~type_: Text
        ~label: "Remark"
        ~placeholder: "Any additional information that doesn't fit in the other fields."
        ~serialise: Fun.id
        ~validate: (S.const % ok)
        () ^::
      Input.prepare
        ~type_: Text
        ~label: "SCDDB ID"
        ~placeholder: "eg. 2423 or https://my.strathspey.org/dd/tune/2423/"
        ~serialise: (Option.fold ~none: "" ~some: string_of_int)
        ~validate: (
          S.const %
            Option.fold
              ~none: (Ok None)
              ~some: (Result.map some % SCDDB.entry_from_string SCDDB.Tune) %
            Option.of_string_nonempty
        )
        () ^::
      nil
    )

let submit mode tune =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Tune Update) id tune;%lwt lwt id
    | _ -> Api.call_exn (Tune Create) tune
  in
  lwt {With_id.id; form = tune}

let unsubmit = lwt % With_id.form

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "tune"
    ~icon: (Entity Tune)
    editor
    ~mode
    ~format: (Formatters.Tune.name ~link: true % With_id.map Tune_form.to_name)
    ~href: (Endpoints.Page.href_tune % With_id.id)
    ~submit
    ~unsubmit

let create_row (mode : (Tune_row.t, 'a) Editor.mode) =
  let%lwt (mode : ((Tune_id.t, Tune_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map Tune_form.to_row)
        )
    | Edit {Tune_row.id; _} ->
      let%lwt form = Api.call_exn (Tune Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (Tune Get_form) id in
  create @@ Edit {With_id.id; form}
