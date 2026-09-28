open Nes
open Dancelor_common
open Model_new
open Components
open Html

let editor =
  let open Editor in
  Input.prepare_non_empty
    ~type_: Text
    ~label: "Name"
    ~placeholder: "eg. John Doe"
    () ^::
  Input.prepare
    ~type_: Text
    ~label: "SCDDB ID"
    ~placeholder: "eg. 9999 or https://my.strathspey.org/dd/person/9999/"
    ~serialise: (Option.fold ~none: "" ~some: string_of_int)
    ~validate: (
      S.const %
        Option.fold
          ~none: (Ok None)
          ~some: (Result.map some % SCDDB.entry_from_string SCDDB.Person) %
        Option.of_string_nonempty
    )
    () ^::
  nil

let assemble (name, (scddb_id, ())) =
  (* FIXME: This is obviously very wrong as it erases the _tunes_are_public information. *)
  Model.Person.make ~name ~scddb_id ~composed_tunes_are_public: false ~published_tunes_are_public: false ()

let submit mode person =
  let%lwt id =
    match mode with
    | Editor.Edit prev_person -> Api.call_exn (Person Update) (Entry.id prev_person) person;%lwt lwt (Entry.id prev_person)
    | _ ->
      Api.call_exn (Person Create) person
  in
  Option.get <$> Model.Person.get id

let unsubmit = lwt % Entry.value

let disassemble person =
  let name = Model.Person.name person in
  let scddb_id = Model.Person.scddb_id person in
  lwt (name, (scddb_id, ()))

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "person"
    ~icon: (Model Person)
    editor
    ~mode
    ~assemble
    ~submit
    ~unsubmit
    ~disassemble
    ~check_product: Model.Person.equal
    ~format: (Formatters.Person.name' ~link: true)
    ~href: (Endpoints.Page.href_person % Entry.id)

let to_name (person : Model.Person.entry) : Person_name.t = {
  Person_name.id = Entry.id person;
  name = NEString.to_string @@ Model.Person.name' person;
}

let create_row (mode : (Person_row.t, 'a) Editor.mode) =
  let%lwt (mode : (Model.Person.entry, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (fun result ->
            let result = {
              Person_row.id = Entry.id result;
              name = NEString.to_string @@ Model.Person.name' result;
            }
            in
            callback result
          )
        )
    | Edit result ->
      let%lwt result = Option.get <$> Model.Person.get (Person_row.id result) in
      lwt @@ Editor.Edit result
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt person = Option.get <$> Model.Person.get id in
  create (Edit person)
