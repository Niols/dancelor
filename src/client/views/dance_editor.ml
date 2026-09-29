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
        ~type_: Text
        ~label: "Name"
        ~placeholder: "eg. The Dusty Miller"
        ()
    ) ^::
  Input.prepare
    ~type_: Text
    ~label: "Kind"
    ~placeholder: "eg. 8x32R or 2x(16R+16S)"
    ~serialise: Kind.Dance.to_string
    ~validate: (
      S.const %
        Option.to_result ~none: "Enter a valid kind, eg. 8x32R or 2x(16R+16S)." %
        Kind.Dance.of_string_opt
    )
    () ^::
  Star.prepare
    ~label: "Devisers"
    (
      Selector.prepare
        ~label: "Deviser"
        ~search: Api.person_search
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: Model_new.Person_row.id
        ~unserialise: (Api.call_or_option @@ Person Get_row)
        ~make_descr: (lwt % Person_row.name)
        ~make_result: (Any_result_new.make_person_result ?in_search: None)
        ~results_when_no_search: (Option.to_list <$> Environment.person_row)
        ~model_name: "person"
        ~create_dialog_content: Person_editor.create_row
        ()
    ) ^::
  Input.prepare_option
    ~type_: Text
    ~label: "Date of devising"
    ~placeholder: "eg. 2019 or 2012-03-14"
    ~serialise: (NEString.of_string_exn % PartialDate.to_string)
    (* FIXME: make PartialDate.to_string return NEString.t *)
    ~validate: (
      S.const %
        Option.to_result ~none: "Enter a valid date, eg. 2019, 2015-10, or 2012-03-14." %
        PartialDate.from_string %
        NEString.to_string
    )
    () ^::
  Input.prepare_option
    ~type_: Text
    ~label: "Disambiguation"
    ~placeholder: "If there are multiple dances with the same name, this field must be used to distinguish them."
    ~serialise: Fun.id
    ~validate: (S.const % ok)
    () ^::
  Choices.prepare_radios
    ~label: "Number of chords"
    [
      Choices.choice ~value: Model.Dance.Dont_know [txt "I don't know"] ~checked: true;
      Choices.choice ~value: Model.Dance.One_chord [txt "One chord"];
      Choices.choice ~value: Model.Dance.Two_chords [txt "Two chords"];
    ] ^::
  Input.prepare
    ~type_: Text
    ~label: "SCDDB ID"
    ~placeholder: "eg. 14298 or https://my.strathspey.org/dd/dance/14298/"
    ~serialise: (Option.fold ~none: "" ~some: string_of_int)
    ~validate: (
      S.const %
        Option.fold
          ~none: (Ok None)
          ~some: (Result.map some % SCDDB.entry_from_string SCDDB.Dance) %
        Option.of_string_nonempty
    )
    () ^::
  nil

let assemble (names, (kind, (devisers, (date, (disambiguation, (two_chords, (scddb_id, ()))))))) =
  let devisers = List.map Person_row.id devisers in
  Model.Dance.make ~names ~kind ~devisers ~two_chords ~scddb_id ~disambiguation ~date ()

let submit mode dance =
  let%lwt id =
    match mode with
    | Editor.Edit prev_dance -> Api.call_exn (Dance Update) (Entry.id prev_dance) dance;%lwt lwt (Entry.id prev_dance)
    | _ -> Api.call_exn (Dance Create) dance
  in
  Option.get <$> Model.Dance.get id

let unsubmit = lwt % Entry.value

let disassemble dance =
  let names = Model.Dance.names dance in
  let kind = Model.Dance.kind dance in
  let%lwt devisers = Lwt_list.map_p (Api.call_exn (Person Get_row)) (Model.Dance.devisers dance) in
  let date = Model.Dance.date dance in
  let disambiguation = Model.Dance.disambiguation dance in
  let two_chords = Model.Dance.two_chords dance in
  let scddb_id = Model.Dance.scddb_id dance in
  lwt (names, (kind, (devisers, (date, (disambiguation, (two_chords, (scddb_id, ())))))))

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "dance"
    ~icon: (Model Dance)
    ~mode
    editor
    ~format: (Formatters.Dance.name' ~link: true)
    ~href: (Endpoints.Page.href_dance % Entry.id)
    ~assemble
    ~submit
    ~unsubmit
    ~disassemble
    ~check_product: Model.Dance.equal

let create_row (mode : (Dance_row.t, 'a) Editor.mode) =
  let%lwt (mode : (Model.Dance.entry, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (fun dance ->
            let%lwt devisers = Lwt_list.map_p (Option.get <%> Model.Person.get) @@ Model.Dance.devisers' dance in
            let devisers = List.map Person_editor.to_name devisers in
            let dance = {
              Dance_row.id = Entry.id dance;
              name = NEString.to_string @@ NEList.hd @@ Model.Dance.names' dance;
              kind = Model.Dance.kind' dance;
              devisers;
              disambiguation = Option.map NEString.to_string @@ Model.Dance.disambiguation' dance;
            }
            in
            callback dance
          )
        )
    | Edit result ->
      let%lwt result = Option.get <$> Model.Dance.get (Dance_row.id result) in
      lwt @@ Editor.Edit result
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt dance = Option.get <$> Model.Dance.get id in
  create (Edit dance)
