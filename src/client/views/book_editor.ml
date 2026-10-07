open Nes
open Dancelor_common
open Components
open Html
open Utils

let (show_preview, set_show_preview) = S.create false
let flip_show_preview () = set_show_preview (not (S.value show_preview))

let versions_and_parameters ?(label = "Versions") () =
  Star.prepare_non_empty
    ~label: "Versions"
    (
      Parameteriser.prepare
        (
          Selector.prepare
            ~make_descr: (lwt % Tune_row.name % Version_row.tune)
            ~make_result: (Tables.version_row ?in_search: None)
            ~make_more_results: (fun version ->
              S.flip_map show_preview @@ function
                | true -> [tr [td ~a: [a_colspan 9999] [Version_snippets.make ~show_audio: false (Version_row.to_name version)]]]
                | false -> []
            )
            ~label
            ~model_name: "version"
            ~create_dialog_content: Version_editor.create_row
            ~search: Api.version_search
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
            ~serialise: Version_row.id
            ~unserialise: (Api.call_or_option @@ Version Get_row)
            ()
        )
        Version_parameters_editor.e
    )

let set_and_parameters ?(label = "Set") () =
  Parameteriser.prepare
    (
      Selector.prepare
        ~make_descr: (lwt % Set_row.name)
        ~make_result: (Tables.set_row ?in_search: None ?params: None)
        ~make_more_results: (fun set ->
          S.flip_map show_preview @@ function
            | true -> [tr [td ~a: [a_colspan 9999] (Formatters.Set.tunes set)]]
            | false -> []
        )
        ~label
        ~model_name: "set"
        ~create_dialog_content: Set_editor.create_row
        ~search: Api.set_search
        ~id_to_yojson: Id.to_yojson'
        ~id_of_yojson: Id.of_yojson'
        ~serialise: Set_row.id
        ~unserialise: (Api.call_or_option @@ Set Get_row)
        ()
    )
    Set_parameters_editor.e

let dance_and_dance_page =
  let open Bundle in
  pair
    ~label: "Dance"
    ~stacking: No_label
    ~wrap: Fun.id
    ~unwrap: Fun.id
    (
      Selector.prepare
        ~make_descr: (lwt % Dance_row.name)
        ~make_result: (Tables.dance_row ?in_search: None)
        ~label: "Dance"
        ~model_name: "dance"
        ~create_dialog_content: Dance_editor.create_row
        ~search: Api.dance_search
        ~id_to_yojson: Id.to_yojson'
        ~id_of_yojson: Id.of_yojson'
        ~serialise: Dance_row.id
        ~unserialise: (Api.call_or_option @@ Dance Get_row)
        ()
    )
    (
      let open Plus.Tuple_elt in
      Plus.prepare
        ~label: "Dance page"
        ~cast: (function
          | Zero() -> Book_form.Dance_only
          | Succ Zero versions_and_params -> Book_form.Dance_versions versions_and_params
          | Succ Succ Zero (set, params) -> Book_form.Dance_set (set, params)
          | _ -> assert false (* types guarantee this is not reachable *)
        )
        ~uncast: (function
          | Book_form.Dance_only -> Zero ()
          | Book_form.Dance_versions versions_and_params -> one versions_and_params
          | Book_form.Dance_set (set, params) -> two (set, params)
        )
        ~selected_when_empty: 0
        (
          let open Plus.Bundle in
          Nil.prepare ~label: "Dance only" () ^::
          versions_and_parameters ~label: "+Versions" () ^::
          set_and_parameters ~label: "+Set" () ^::
          nil
        )
    )

let editor =
  let open Bundle in
  group
    ~wrap: (fun (name, (authors, (date, (contents, (remark, (sources, (scddb_id, ()))))))) ->
      {Book_form.name; authors; date; contents; remark; sources; scddb_id}
    )
    ~unwrap: (fun {Book_form.name; authors; date; contents; remark; sources; scddb_id} ->
      (name, (authors, (date, (contents, (remark, (sources, (scddb_id, ())))))))
    )
    ~check: Book_form.equal
    (
      Input.prepare_non_empty
        ~type_: Text
        ~label: "Name"
        ~placeholder: "eg. The Dusty Miller Book"
        () ^::
      Star.prepare
        ~label: "Editors"
        (
          Selector.prepare
            ~label: "Editor"
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
      Input.prepare
        ~type_: Text
        ~label: "Date of publication"
        ~placeholder: "eg. 2019 or 2012-03-14"
        ~serialise: (Option.fold ~none: "" ~some: Partial_date.to_string)
        ~validate: (
          S.const %
            Option.fold
              ~none: (Ok None)
              ~some: (Result.map some % Option.to_result ~none: "Not a valid date" % Partial_date.from_string) %
            Option.of_string_nonempty
        )
        () ^::
      Star.prepare
        ~label: "Contents"
        ~make_header: (fun n -> div ~a: [a_class (if n = 0 then [] else ["pt-1"; "mt-1"; "border-top"])] [txtf "Page %d" (n + 1)])
        (
          let open Plus.Tuple_elt in
          Plus.prepare
            ~label: "Page"
            ~cast: (function
              | Zero title -> Book_form.Part title
              | Succ Zero (dance, dance_page) -> Book_form.Dance (dance, dance_page)
              | Succ Succ Zero versions_and_params -> Book_form.Versions versions_and_params
              | Succ Succ Succ Zero (set, params) -> Book_form.Set (set, params)
              | _ -> assert false (* types guarantee this is not reachable *)
            )
            ~uncast: (function
              | Book_form.Part title -> Zero title
              | Book_form.Dance (dance, dance_page) -> one (dance, dance_page)
              | Book_form.Versions versions_and_params -> two versions_and_params
              | Book_form.Set (set, params) -> three (set, params)
            )
            (
              let open Plus.Bundle in
              Input.prepare_non_empty
                ~type_: Text
                ~label: "Part"
                ~placeholder: "eg. Part CMXCVII"
                () ^::
              dance_and_dance_page ^::
              versions_and_parameters () ^::
              set_and_parameters () ^::
              nil
            )
        )
        ~more_actions: (
          let flip_show_preview_button ~icon =
            Button.make
              ~classes: ["btn-info"]
              ~icon
              ~tooltip: "Toggle the preview of sets and versions. This can take a lot of space on the page and is therefore disabled by default."
              ~onclick: (fun _ -> flip_show_preview (); lwt_unit)
              ()
          in
          S.flip_map show_preview @@ function
            | true -> [flip_show_preview_button ~icon: (Action Preview)]
            | false -> [flip_show_preview_button ~icon: (Action No_preview)]
        ) ^::
      Input.prepare_option
        ~type_: Text
        ~label: "Remark"
        ~placeholder: "eg. Dusty Miller"
        ~serialise: Fun.id
        ~validate: (S.const % ok)
        () ^::
      Star.prepare
        ~label: "Sources"
        (
          Selector.prepare
            ~make_descr: (lwt % Source_row.name)
            ~make_result: (Tables.source_row ?in_search: None)
            ~label: "Source"
            ~model_name: "source"
            ~create_dialog_content: Source_editor.create_row
            ~search: Api.source_search
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
            ~serialise: Source_row.id
            ~unserialise: (Api.call_or_option @@ Source Get_row)
            ()
        ) ^::
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
      nil
    )

let submit mode book =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Book Update) id book;%lwt lwt id
    | _ -> Api.call_exn (Book Create) book
  in
  lwt {With_id.id; form = book}

let unsubmit = lwt % With_id.form

let create mode =
  (* FIXME: if [mode] is an edition, then we should [assert_can_update_public] *)
  (* FIXME: reintroduce the [?pre_body] explaining why the actor is allowed to
     edit; maybe just via a helper [assert_can_create_private]? *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "book"
    ~icon: (Entity Book)
    editor
    ~mode
    ~format: (Formatters.Book.name % With_id.map Book_form.to_name)
    ~href: (Endpoints.Page.href_book % With_id.id)
    ~submit
    ~unsubmit

(* match mode with *)
(* | Create _ | Create_with_local_storage | Quick_create _ -> *)
(*   Main_page.assert_can_create_private make_editor *)
(* | Quick_edit _ -> *)
(*   (\* FIXME: I guess we should be able to check permissions like for Edit. *\) *)
(*   Main_page.assert_can_create_private make_editor *)
(* | Edit book -> *)
(*   let%lwt permission = Set_editor.entry_permission book in *)
(*   Main_page.assert_can_update permission @@ fun edit_reason -> *)
(*   let pre_body = *)
(*     match edit_reason with *)
(*     | Owner -> [] *)
(*     | Omniscient_administrator -> [div ~a: [a_class ["mb-4"]] [Alert.make ~level: Warning [txt "You are editing this book as an omniscient administrator."]]] *)
(*   in *)
(*   make_editor ~pre_body () *)

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (Book Get_form) id in
  create @@ Edit {With_id.id; form}
