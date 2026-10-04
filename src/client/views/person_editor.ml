open Nes
open Dancelor_common
open Components
open Html

let editor =
  let open Bundle in
  group
    ~wrap: (fun (name, (scddb_id, ())) -> {Person_form.name; scddb_id})
    ~unwrap: (fun {Person_form.name; scddb_id} -> (name, (scddb_id, ())))
    ~check: Person_form.equal
    (
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
    )

let submit mode person =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Person Update) id person;%lwt lwt id
    | _ -> Api.call_exn (Person Create) person
  in
  lwt {With_id.id; form = person}

let unsubmit = lwt % With_id.form

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "person"
    ~icon: (Model Person)
    editor
    ~mode
    ~submit
    ~unsubmit
    ~format: (Formatters.Person.name ~link: true % With_id.map Person_form.to_name)
    ~href: (Endpoints.Page.href_person % With_id.id)

let create_row (mode : (Person_row.t, 'a) Editor.mode) =
  let%lwt (mode : ((Person_id.t, Person_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map Person_form.to_row)
        )
    | Edit {Person_row.id; _} ->
      let%lwt form = Api.call_exn (Person Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (Person Get_form) id in
  create @@ Edit {With_id.id; form}
