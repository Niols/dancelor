open Nes
open Dancelor_common
module Model = Model_builder.Core
open Components
open Html
open Utils

let editor =
  let open Bundle in
  group
    ~wrap: (fun (name, (short_name, (editors, (date, (scddb_id, (description, ())))))) ->
      {Source_form.name; short_name; editors; scddb_id; description; date}
    )
    ~unwrap: (fun {Source_form.name; short_name; editors; date; scddb_id; description} ->
      (name, (short_name, (editors, (date, (scddb_id, (description, ()))))))
    )
    ~check: Source_form.equal
    (
      Input.prepare_non_empty
        ~type_: Text
        ~label: "Name"
        ~placeholder: "eg. The Paris Book of Scottish Country Dances, volume 2"
        () ^::
      Input.prepare_option
        ~type_: Text
        ~label: "Short name"
        ~placeholder: "eg. Paris Book 2"
        ~serialise: id
        ~validate: (S.const % ok)
        () ^::
      Star.prepare
        ~label: "Editors"
        (
          Selector.prepare
            ~label: "Editor"
            ~search: Api.person_search
            ~id_to_yojson: Entry.Id.to_yojson'
            ~id_of_yojson: Entry.Id.of_yojson'
            ~serialise: Person_row.id
            ~unserialise: (Api.call_or_option @@ Person Get_row)
            ~make_descr: (lwt % Person_row.name)
            ~make_result: (Any_result.make_person_result ?in_search: None)
            ~results_when_no_search: (Option.to_list <$> Environment.person)
            ~model_name: "person"
            ~create_dialog_content: Person_editor.create_row
            ()
        ) ^::
      Input.prepare
        ~type_: Text
        ~label: "Date of publication"
        ~placeholder: "eg. 2019 or 2012-03-14"
        ~serialise: (Option.fold ~none: "" ~some: PartialDate.to_string)
        ~validate: (
          S.const %
            Option.fold
              ~none: (Ok None)
              ~some: (Result.map some % Option.to_result ~none: "Not a valid date" % PartialDate.from_string) %
            Option.of_string_nonempty
        )
        () ^::
      Input.prepare
        ~type_: Text
        ~label: "SCDDB ID"
        ~placeholder: "eg. 9999 or https://my.strathspey.org/dd/publication/9999/"
        ~serialise: (Option.fold ~none: "" ~some: string_of_int)
        ~validate: (
          S.const %
            Option.fold
              ~none: (Ok None)
              ~some: (Result.map some % SCDDB.entry_from_string SCDDB.Publication) %
            Option.of_string_nonempty
        )
        () ^::
      Input.prepare
        ~type_: (Textarea {rows = 10})
        ~label: "Description"
        ~placeholder: "eg. Book provided by the RSCDS and containing almost all of the original tunes for the RSCDS dances. New editions come every now and then to add tunes for newly introduced RSCDS dances."
        ~serialise: (Option.value ~default: "")
        ~validate: (S.const % function "" -> Ok None | s -> Ok (Some s))
        () ^::
      nil
    )

let submit mode source =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Source Update) id source;%lwt lwt id
    | _ -> Api.call_exn (Source Create) source
  in
  lwt {With_id.id; form = source}

let unsubmit = lwt % With_id.form

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "source"
    ~icon: (Model Source)
    editor
    ~mode
    ~submit
    ~unsubmit
    ~format: (Formatters.Source.name ~link: true % With_id.map Source_form.to_name)
    ~href: (Endpoints.Page.href_source % With_id.id)

let to_short_name (source : Model.Source.entry) : Source_short_name.t = {
  Source_short_name.id = Entry.id source;
  short_name =
  NEString.to_string (
    match Model.Source.short_name' source with
    | None -> Model.Source.name' source
    | Some name -> name
  );
}

let create_row (mode : (Source_row.t, 'a) Editor.mode) =
  let%lwt (mode : ((Source_id.t, Source_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map Source_form.to_row)
        )
    | Edit {Source_row.id; _} ->
      let%lwt form = Api.call_exn (Source Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (Source Get_form) id in
  create @@ Edit {With_id.id; form}
