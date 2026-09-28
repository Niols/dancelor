open Nes
open Dancelor_common
open Model_new
open Components
open Html
open Utils

let editor =
  let open Editor in
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
    ~label: "Composer"
    (
      Cpair.prepare
        ~label: "Composer"
        (
          Selector.prepare
            ~make_descr: (lwt % Person_row.name)
            ~make_result: (Any_result_new.make_person_result ?in_search: None)
            ~results_when_no_search: (Option.to_list <$> Environment.person_row)
            ~label: "Composer"
            ~model_name: "person"
            ~create_dialog_content: Person_editor.create_row
            ~search: Api.person_search
            ~id_to_yojson: Entry.Id.to_yojson'
            ~id_of_yojson: Entry.Id.of_yojson'
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
    ~serialise: (Option.fold ~none: "" ~some: PartialDate.to_string)
    ~validate: (
      S.const %
        Option.fold
          ~none: (Ok None)
          ~some: (Result.map some % Option.to_result ~none: "Enter a valid date, eg. 2019 or 2012-03-14" % PartialDate.from_string) %
        Option.of_string_nonempty
    )
    () ^::
  Star.prepare
    ~label: "Dances"
    (
      Selector.prepare
        ~search: Api.dance_search
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: Dance_row.id
        ~unserialise: (Api.call_or_option @@ Dance Get_row)
        ~make_descr: (lwt % Dance_row.name)
        ~make_result: (Any_result_new.make_dance_result ?in_search: None)
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

let assemble (names, (kind, (composers, (date, (dances, (remark, (scddb_id, ()))))))) =
  let composers = List.map (fun (composer, details) -> {Model.Tune.composer = Person_row.id composer; details}) composers in
  let dances = List.map Dance_row.id dances in
  Model.Tune.make ~names ~kind ~composers ~date ~dances ~remark ~scddb_id ()

let submit mode tune =
  let%lwt id =
    match mode with
    | Editor.Edit prev_tune -> Api.call_exn (Tune Update) (Entry.id prev_tune) tune;%lwt lwt (Entry.id prev_tune)
    | _ -> Api.call_exn (Tune Create) tune
  in
  Api.call_exn (Tune Get) id

let unsubmit = lwt % Entry.value

let disassemble tune =
  let names = Model.Tune.names tune in
  let kind = Model.Tune.kind tune in
  let%lwt composers =
    Lwt_list.map_p
      (fun Model.Tune.{composer; details} ->
        let%lwt composer = Api.call_exn (Person Get_row) composer in
        lwt (composer, details)
      )
      (Model.Tune.composers tune)
  in
  let date = Model.Tune.date tune in
  let%lwt dances = Lwt_list.map_p (Api.call_exn (Dance Get_row)) (Model.Tune.dances tune) in
  let remark = Model.Tune.remark tune in
  let scddb_id = Model.Tune.scddb_id tune in
  lwt (names, (kind, (composers, (date, (dances, (remark, (scddb_id, ())))))))

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "tune"
    ~icon: (Model Tune)
    editor
    ~mode
    ~format: (Formatters.Tune.name' ~link: true)
    ~href: (Endpoints.Page.href_tune % Entry.id)
    ~assemble
    ~submit
    ~unsubmit
    ~disassemble
    ~check_product: Model.Tune.equal

let to_row tune =
  let%lwt composers = Lwt_list.map_s (Option.get <%> Model.Person.get % Model.Tune.composer_composer) @@ Model.Tune.composers' tune in
  let composers = List.map Person_editor.to_name composers in
  lwt {
    Tune_row.id = Entry.id tune;
    name = NEString.to_string @@ NEList.hd @@ Model.Tune.names' tune;
    kind = Model.Tune.kind' tune;
    composers;
  }

let create_row (mode : (Tune_row.t, 'a) Editor.mode) =
  let%lwt (mode : (Model.Tune.entry, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (fun tune -> callback =<< to_row tune)
        )
    | Edit result ->
      let%lwt result = Option.get <$> Model.Tune.get (Tune_row.id result) in
      lwt @@ Editor.Edit result
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt tune = Option.get <$> Model.Tune.get id in
  create (Edit tune)
