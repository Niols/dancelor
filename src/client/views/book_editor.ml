open Nes
open Dancelor_common
open Model_new
open Search_new
open Components
open Html
open Utils

let (show_preview, set_show_preview) = S.create false
let flip_show_preview () = set_show_preview (not (S.value show_preview))

type visibility' =
  | Owners_only
  | Everyone
  | Select_viewers of User_row.t NEList.t

let visibility'_to_visibility : visibility' -> Entry.Access.Private.visibility = function
  | Owners_only -> Owners_only
  | Everyone -> Everyone
  | Select_viewers users -> Select_viewers (NEList.map User_row.id users)

let visibility_to_visibility' : Entry.Access.Private.visibility -> visibility' Lwt.t = function
  | Owners_only -> lwt Owners_only
  | Everyone -> lwt Everyone
  | Select_viewers users ->
    let%lwt users = Monadise_lwt.lift_1_1 NEList.map (Madge_client.call_exn Endpoints.Api.(route @@ User Get_row)) users in
    lwt (Select_viewers users)

let model_content_to_content =
  Lwt_list.map_p @@ function
    | Model.Book.Part title ->
      lwt @@ `Part title
    | Dance (dance, Dance_only) ->
      let%lwt dance = Madge_client.call_exn Endpoints.Api.(route @@ Dance Get_row) dance in
      lwt @@ `Dance (dance, `Dance_only)
    | Dance (dance, Dance_versions versions_and_params) ->
      let%lwt dance = Madge_client.call_exn Endpoints.Api.(route @@ Dance Get_row) dance in
      let%lwt versions_and_params =
        Monadise_lwt.run @@ fun () ->
        NEList.map (Pair.map_fst (Monadise_lwt.yield % Madge_client.call_exn Endpoints.Api.(route @@ Version Get_row))) versions_and_params
      in
      lwt @@ `Dance (dance, `Dance_versions versions_and_params)
    | Dance (dance, Dance_set (set, params)) ->
      let%lwt dance = Madge_client.call_exn Endpoints.Api.(route @@ Dance Get_row) dance in
      let%lwt set = Madge_client.call_exn Endpoints.Api.(route @@ Set Get_row) set in
      lwt @@ `Dance (dance, `Dance_set (set, params))
    | Versions versions_and_params ->
      let%lwt versions_and_params =
        Monadise_lwt.run @@ fun () ->
        NEList.map (Pair.map_fst (Monadise_lwt.yield % Madge_client.call_exn Endpoints.Api.(route @@ Version Get_row))) versions_and_params
      in
      lwt @@ `Versions versions_and_params
    | Set (set, params) ->
      let%lwt set = Madge_client.call_exn Endpoints.Api.(route @@ Set Get_row) set in
      lwt @@ `Set (set, params)

let content_to_model_content =
  List.map @@ function
    | `Part title -> Model.Book.Part title
    | `Dance (dance, `Dance_only) -> Model.Book.Dance (Dance_row.id dance, Dance_only)
    | `Dance (dance, `Dance_versions versions_and_params) -> Model.Book.Dance (Dance_row.id dance, Dance_versions (NEList.map (Pair.map_fst Version_row.id) versions_and_params))
    | `Dance (dance, `Dance_set (set, params)) -> Model.Book.Dance (Dance_row.id dance, Dance_set (Set_row.id set, params))
    | `Versions versions_and_params -> Model.Book.Versions (NEList.map (Pair.map_fst Version_row.id) versions_and_params)
    | `Set (set, params) -> Model.Book.Set (Set_row.id set, params)

let versions_and_parameters ?(label = "Versions") () =
  Star.prepare_non_empty
    ~label: "Versions"
    (
      Parameteriser.prepare
        (
          Selector.prepare
            ~make_descr: (lwt % Tune_row.name % Version_row.tune)
            ~make_result: (Any_result_new.make_version_result ?in_search: None)
            ~make_more_results: (fun version ->
              S.flip_map show_preview @@ function
                | true -> [tr [td ~a: [a_colspan 9999] [Version_snippets.make ~show_audio: false (Version_row.to_name version)]]]
                | false -> []
            )
            ~label
            ~model_name: "version"
            ~create_dialog_content: Version_editor.create_row
            ~search: (fun slice query ->
              match Version_query.parse query with
              | Error msg -> lwt_error msg
              | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ Version Search) slice query
            )
            ~id_to_yojson: Entry.Id.to_yojson'
            ~id_of_yojson: Entry.Id.of_yojson'
            ~serialise: Version_row.id
            ~unserialise: (madge_call_or_option @@ Version Get_row)
            ()
        )
        Version_parameters_editor.e
    )

let set_and_parameters ?(label = "Set") () =
  Parameteriser.prepare
    (
      Selector.prepare
        ~make_descr: (lwt % Set_row.name)
        ~make_result: (Any_result_new.make_set_result ?in_search: None ?params: None)
        ~make_more_results: (fun set ->
          S.flip_map show_preview @@ function
            | true -> [tr [td ~a: [a_colspan 9999] (Formatters_new.Set.tunes set)]]
            | false -> []
        )
        ~label
        ~model_name: "set"
        ~create_dialog_content: Set_editor.create_row
        ~search: (fun slice query ->
          match Set_query.parse query with
          | Error msg -> lwt_error msg
          | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ Set Search) slice query
        )
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: Set_row.id
        ~unserialise: (madge_call_or_option @@ Set Get_row)
        ()
    )
    Set_parameters_editor.e

(* ~cast: (function *)
(*   | Zero() -> Model.Book.Dance_only *)
(*   | Succ Zero versions_and_params -> Model.Book.Dance_versions versions_and_params *)
(*   | Succ Succ Zero (set, params) -> Model.Book.Dance_set (set, params) *)
(*   | _ -> assert false (\* types guarantee this is not reachable *\) *)
(* ) *)
(* ~uncast: (function *)
(*   | Model.Book.Dance_only -> Zero () *)
(*   | Model.Book.Dance_versions versions_and_params -> one versions_and_params *)
(*   | Model.Book.Dance_set (set, params) -> two (set, params) *)
(* ) *)

let dance_and_dance_page =
  let open Plus.Bundle in
  Cpair.prepare
    ~label: "Dance"
    (
      Selector.prepare
        ~make_descr: (lwt % Dance_row.name)
        ~make_result: (Any_result_new.make_dance_result ?in_search: None)
        ~label: "Dance"
        ~model_name: "dance"
        ~create_dialog_content: Dance_editor.create_row
        ~search: (fun slice query ->
          match Dance_query.parse query with
          | Error msg -> lwt_error msg
          | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ Dance Search) slice query
        )
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: Dance_row.id
        ~unserialise: (madge_call_or_option @@ Dance Get_row)
        ()
    )
    (
      let open Plus.Tuple_elt in
      Plus.prepare
        ~label: "Dance page"
        ~cast: (function
          | Zero() -> `Dance_only
          | Succ Zero versions_and_params -> `Dance_versions versions_and_params
          | Succ Succ Zero (set, params) -> `Dance_set (set, params)
          | _ -> assert false (* types guarantee this is not reachable *)
        )
        ~uncast: (function
          | `Dance_only -> Zero ()
          | `Dance_versions versions_and_params -> one versions_and_params
          | `Dance_set (set, params) -> two (set, params)
        )
        ~selected_when_empty: 0
        (
          Nil.prepare ~label: "Dance only" () ^::
          versions_and_parameters ~label: "+Versions" () ^::
          set_and_parameters ~label: "+Set" () ^::
          nil
        )
    )

let editor user =
  let open Editor in
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
        ~search: (fun slice query ->
          match Person_query.parse query with
          | Error msg -> lwt_error msg
          | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ Person Search) slice query
        )
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: Person_row.id
        ~unserialise: (madge_call_or_option @@ Person Get_row)
        ~make_descr: (lwt % Person_row.name)
        ~make_result: (Any_result_new.make_person_result ?in_search: None)
        ~results_when_no_search: (Option.to_list <$> Environment.person_row)
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
  Star.prepare
    ~label: "Contents"
    ~make_header: (fun n -> div ~a: [a_class (if n = 0 then [] else ["pt-1"; "mt-1"; "border-top"])] [txtf "Page %d" (n + 1)])
    (
      let open Plus.Tuple_elt in
      Plus.prepare
        ~label: "Page"
        ~cast: (function
          | Zero title -> `Part title
          | Succ Zero (dance, dance_page) -> `Dance (dance, dance_page)
          | Succ Succ Zero versions_and_params -> `Versions versions_and_params
          | Succ Succ Succ Zero (set, params) -> `Set (set, params)
          | _ -> assert false (* types guarantee this is not reachable *)
        )
        ~uncast: (function
          | `Part title -> Zero title
          | `Dance (dance, dance_page) -> one (dance, dance_page)
          | `Versions versions_and_params -> two versions_and_params
          | `Set (set, params) -> three (set, params)
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
          ~tooltip: "Toggle the preview of sets and versions. This can take a \
                     lot of space on the page and is therefore disabled by \
                     default."
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
  Star.prepare_non_empty
    ~label: "Owners"
    ~empty: [user]
    (
      Selector.prepare
        ~label: "Owner"
        ~model_name: "user"
        ~make_descr: (fun user -> lwt @@ Username.to_string user.username)
        ~make_result: (Any_result_new.make_user_result ?in_search: None)
        ~results_when_no_search: (Option.to_list <$> Environment.user_new)
        ~search: (fun slice input ->
          match User_query.parse input with
          | Error msg -> lwt_error msg
          | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ User Search) slice query
        )
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: User_row.id
        ~unserialise: (madge_call_or_option @@ User Get_row)
        ()
    ) ^::
  (
    let open Plus.Bundle in
    let open Plus.Tuple_elt in
    Plus.prepare
      ~label: "Visibility"
      ~cast: (function
        | Zero() -> Owners_only
        | Succ Zero() -> Everyone
        | Succ Succ Zero viewers -> Select_viewers viewers
        | _ -> assert false (* types guarantee this is not reachable *)
      )
      ~uncast: (function
        | Owners_only -> Zero ()
        | Everyone -> one ()
        | Select_viewers viewers -> two viewers
      )
      ~selected_when_empty: 0
      (
        Nil.prepare ~label: "Owners only" () ^::
        Nil.prepare ~label: "Everyone" () ^::
        (
          Star.prepare_non_empty
            ~label: "Viewers"
            (
              Selector.prepare
                ~label: "Viewer"
                ~model_name: "user"
                ~make_descr: (fun user -> lwt @@ Username.to_string user.username)
                ~make_result: (Any_result_new.make_user_result ?in_search: None)
                ~search: (fun slice input ->
                  match User_query.parse input with
                  | Error msg -> lwt_error msg
                  | Ok query -> ok <$> Madge_client.call_exn Endpoints.Api.(route @@ User Search) slice query
                )
                ~id_to_yojson: Entry.Id.to_yojson'
                ~id_of_yojson: Entry.Id.of_yojson'
                ~serialise: User_row.id
                ~unserialise: (madge_call_or_option @@ User Get_row)
                ()
            )
        ) ^::
        nil
      )
  ) ^::
  nil

let assemble (name, (authors, (date, (contents, (remark, (sources, (scddb_id, (owners, (visibility, ()))))))))) =
  let authors = List.map Person_row.id authors in
  let sources = List.map Source_row.id sources in
  let contents = content_to_model_content contents in
  (
    Model.Book.make ~name ~authors ~date ~contents ~remark ~sources ~scddb_id (),
    Entry.Access.Private.make ~owners: (NEList.map User_row.id owners) ~visibility: (visibility'_to_visibility visibility) ()
  )

let submit mode (book, access) =
  let%lwt id =
    match mode with
    | Editor.Edit prev_book ->
      Madge_client.call_exn Endpoints.Api.(route @@ Book Update) (Entry.id prev_book) book access;%lwt
      lwt (Entry.id prev_book)
    | _ -> Madge_client.call_exn Endpoints.Api.(route @@ Book Create) book access
  in
  Madge_client.call_exn Endpoints.Api.(route @@ Book Get) id

let unsubmit entry =
  lwt (Entry.value entry, Entry.access entry)

let disassemble (book, access) =
  let name = Model.Book.name book in
  let%lwt authors = Lwt_list.map_p (Madge_client.call_exn Endpoints.Api.(route @@ Person Get_row)) (Model.Book.authors book) in
  let date = Model.Book.date book in
  let%lwt contents = model_content_to_content @@ Model.Book.contents book in
  let remark = Model.Book.remark book in
  let%lwt sources = Lwt_list.map_p (Madge_client.call_exn Endpoints.Api.(route @@ Source Get_row)) (Model.Book.sources book) in
  let scddb_id = Model.Book.scddb_id book in
  let%lwt owners = NEList.of_list_exn <$> Lwt_list.map_p (Madge_client.call_exn Endpoints.Api.(route @@ User Get_row)) (NEList.to_list @@ Entry.Access.Private.owners access) in
  let%lwt visibility = visibility_to_visibility' @@ Entry.Access.Private.visibility access in
  lwt (name, (authors, (date, (contents, (remark, (sources, (scddb_id, (owners, (visibility, ())))))))))

let create mode =
  let%lwt user = Option.map Entry.id <$> Environment.user in
  let make_editor = fun ?pre_body () ->
    Editor.make_page
      ~key: "book"
      ~icon: (Model Book)
      (editor user)
      ~mode
      ~format: Formatters.Book.name'
      ~href: (Endpoints.Page.href_book % Entry.id)
      ~assemble
      ~submit
      ~unsubmit
      ~disassemble
      ~check_product: (fun (book1, access1) (book2, access2) -> Model.Book.equal book1 book2 && Entry.Access.Private.equal access1 access2)
      ?pre_body
  in
  match mode with
  | Create _ | Create_with_local_storage | Quick_create _ ->
    Main_page.assert_can_create_private make_editor
  | Quick_edit _ ->
    (* FIXME: I guess we should be able to check permissions like for Edit. *)
    Main_page.assert_can_create_private make_editor
  | Edit book ->
    let%lwt permission = Set_editor.entry_permission_new book in
    Main_page.assert_can_update permission @@ fun edit_reason ->
    let pre_body =
      match edit_reason with
      | Owner -> []
      | Omniscient_administrator -> [div ~a: [a_class ["mb-4"]] [Alert.make ~level: Warning [txt "You are editing this book as an omniscient administrator."]]]
    in
    make_editor ~pre_body ()

let add () =
  create Create_with_local_storage

let edit book_id =
  let%lwt book = Option.get <$> Model.Book.get book_id in
  create (Edit book)
