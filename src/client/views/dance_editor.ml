open Nes
open Dancelor_common
open Components
open Html
open Utils

(* HACK: The tune and the dance editor have a dependency cycle, so we break it
   with this, but that is a bit disgusting. Sadly, we need to know the type of
   the state of the tune editor also. *)
let tune_editor_create_row_ref
    : ((Tune_row.t, string list
    * (bool list
    * ((Person_id.t option * (string * unit)) list
    * (string
    * (Dance_id.t option list
    *
      (string * (string * unit))))))) Editor.mode ->
    Page.t Lwt.t) option ref
  =
  ref None
let tune_editor_create_row mode =
  match !tune_editor_create_row_ref with
  | None -> failwith "Dance_editor.tune_editor_create_row"
  | Some f -> f mode

let editor =
  let open Bundle in
  group
    ~wrap: (fun (names, (kind, (devisers, (tunes, (date, (disambiguation, (two_chords, (scddb_id, ())))))))) ->
      {Dance_form.names; kind; devisers; tunes; two_chords; scddb_id; disambiguation; date}
    )
    ~unwrap: (fun {Dance_form.names; kind; devisers; tunes; two_chords; scddb_id; disambiguation; date} ->
      (names, (kind, (devisers, (tunes, (date, (disambiguation, (two_chords, (scddb_id, ()))))))))
    )
    ~check: Dance_form.equal
    (
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
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
            ~serialise: Person_row.id
            ~unserialise: (Api.call_or_option @@ Person Get_row)
            ~make_descr: (lwt % Person_row.name)
            ~make_result: (Tables.person_row ?in_search: None)
            ~results_when_no_search: (Option.to_list <$> Environment.person)
            ~model_name: "person"
            ~create_dialog_content: Person_editor.create_row
            ()
        ) ^::
      Star.prepare
        ~label: "Recommended tunes"
        (
          Selector.prepare
            ~label: "Tune"
            ~search: Api.tune_search
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
            ~serialise: Tune_row.id
            ~unserialise: (Api.call_or_option @@ Tune Get_row)
            ~make_descr: (lwt % Tune_row.name)
            ~make_result: (Tables.tune_row ?in_search: None)
            ~model_name: "tune"
            ~create_dialog_content: tune_editor_create_row
            ()
        ) ^::
      Input.prepare_option
        ~type_: Text
        ~label: "Date of devising"
        ~placeholder: "eg. 2019 or 2012-03-14"
        ~serialise: (NEString.of_string_exn % Partial_date.to_string)
        (* FIXME: make PartialDate.to_string return NEString.t *)
        ~validate: (
          S.const %
            Option.to_result ~none: "Enter a valid date, eg. 2019, 2015-10, or 2012-03-14." %
            Partial_date.from_string %
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
          Choices.choice ~value: Dance_view.Dont_know [txt "I don't know"] ~checked: true;
          Choices.choice ~value: Dance_view.One_chord [txt "One chord"];
          Choices.choice ~value: Dance_view.Two_chords [txt "Two chords"];
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
    )

let submit mode dance =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Dance Update) id dance;%lwt lwt id
    | _ -> Api.call_exn (Dance Create) dance
  in
  lwt {With_id.id; form = dance}

let unsubmit = lwt % With_id.form

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "dance"
    ~icon: (Entity Dance)
    ~mode
    editor
    ~format: (Formatters.Dance.name ~link: true % With_id.map Dance_form.to_name)
    ~href: (Endpoints.Page.href_dance % With_id.id)
    ~submit
    ~unsubmit

let create_row (mode : (Dance_row.t, 'a) Editor.mode) =
  let%lwt (mode : ((Dance_id.t, Dance_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map Dance_form.to_row)
        )
    | Edit {Dance_row.id; _} ->
      let%lwt form = Api.call_exn (Dance Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (Dance Get_form) id in
  create @@ Edit {With_id.id; form}
