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
  | Select_viewers users -> Select_viewers (NEList.map (fun user -> user.User_row.id) users)

let visibility_to_visibility' : Entry.Access.Private.visibility -> visibility' Lwt.t = function
  | Owners_only -> lwt Owners_only
  | Everyone -> lwt Everyone
  | Select_viewers users ->
    let%lwt users = Monadise_lwt.lift_1_1 NEList.map (Madge_client.call_exn Endpoints.Api.(route @@ User Get_row)) users in
    lwt (Select_viewers users)

let editor user =
  let open Editor in
  Input.prepare_non_empty
    ~type_: Text
    ~label: "Name"
    ~placeholder: "eg. The Dusty Miller"
    () ^::
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
    ~label: "Conceptors"
    (
      Selector.prepare
        ~make_descr: (lwt % Person_row.name)
        ~make_result: (Any_result_new.make_person_result ?in_search: None)
        ~results_when_no_search: (Option.to_list <$> Environment.person_row)
        ~label: "Conceptor"
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
  Star.prepare
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
            ~label: "Version"
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
        (
          Version_parameters_editor.e
        )
    )
    ~more_actions: (
      let flip_show_preview_button ~icon =
        Button.make
          ~classes: ["btn-info"]
          ~icon
          ~tooltip: "Toggle the preview of versions. This can take a lot of \
                     space on the page and is therefore disabled by default."
          ~onclick: (fun _ -> flip_show_preview (); lwt_unit)
          ()
      in
      S.flip_map show_preview @@ function
        | true -> [flip_show_preview_button ~icon: (Action Preview)]
        | false -> [flip_show_preview_button ~icon: (Action No_preview)]
    ) ^::
  Input.prepare
    ~type_: Text
    ~label: "Order"
    ~placeholder: "eg. 1,2,3,4,2,3,4,1"
    ~serialise: Model.Set_order.to_string
    ~validate: (
      S.const %
        Option.to_result ~none: "Not a valid order." %
        Model.Set_order.of_string_opt
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

let assemble (name, (kind, (conceptors, (contents, (order, (owners, (visibility, ()))))))) =
  let conceptors = List.map Person_row.id conceptors in
  let contents = List.map (Pair.map_fst Version_row.id) contents in
  (
    (* FIXME: This erases the existing remarks, or, most likely, tunes with
       remarks will get a Non_convertible exception when we check for the roundtrip. *)
    Model.Set.make ~name ~kind ~conceptors ~contents ~order ~remark: None (),
    Entry.Access.Private.make ~owners: (NEList.map User_row.id owners) ~visibility: (visibility'_to_visibility visibility) ()
  )

let submit mode (set, access) =
  let%lwt id =
    match mode with
    | Editor.Edit prev_set ->
      Madge_client.call_exn Endpoints.Api.(route @@ Set Update) (Entry.id prev_set) set access;%lwt
      lwt (Entry.id prev_set)
    | _ -> Madge_client.call_exn Endpoints.Api.(route @@ Set Create) set access
  in
  Madge_client.call_exn Endpoints.Api.(route @@ Set Get) id

let unsubmit entry =
  lwt (Entry.value entry, Entry.access entry)

let disassemble (set, access) =
  let name = Model.Set.name set in
  let kind = Model.Set.kind set in
  let%lwt conceptors = Lwt_list.map_p (Madge_client.call_exn Endpoints.Api.(route @@ Person Get_row)) (Model.Set.conceptors set) in
  let%lwt contents = Lwt_list.map_p (fun (version, params) -> let%lwt version = Madge_client.call_exn Endpoints.Api.(route @@ Version Get_row) version in lwt (version, params)) (Model.Set.contents set) in
  let order = Model.Set.order set in
  let%lwt owners = NEList.of_list_exn <$> Lwt_list.map_p (Madge_client.call_exn Endpoints.Api.(route @@ User Get_row)) (NEList.to_list @@ Entry.Access.Private.owners access) in
  let%lwt visibility = visibility_to_visibility' @@ Entry.Access.Private.visibility access in
  lwt (name, (kind, (conceptors, (contents, (order, (owners, (visibility, ())))))))

let entry_permission_new entry =
  let access = Entry.access entry in
  let visibility = Entry.Access.Private.visibility access in
  let is_public = match visibility with Everyone -> true | _ -> false in
  let%lwt actor_role, user_is_omniscient_administrator =
    match%lwt Environment.user with
    | None -> lwt (None, false)
    | Some user ->
      lwt (
        (
          if NEList.exists (Entry.Id.equal' (Entry.id user)) (Entry.Access.Private.owners access) then
            Some (Owner : Permission_new.actor_role)
          else
            match visibility with
            | Select_viewers viewers when NEList.exists (Entry.Id.equal' (Entry.id user)) viewers ->
              Some (Viewer : Permission_new.actor_role)
            | _ -> None
        ),
        Model.User.is_omniscient_administrator' user
      )
  in
  lwt @@ Permission_new.make ~is_public ~actor_role ~user_is_omniscient_administrator

let create mode =
  let%lwt user = Option.map Entry.id <$> Environment.user in
  let make_editor = fun ?pre_body () ->
    Editor.make_page
      ~key: "set"
      ~icon: (Model Set)
      ~mode
      (editor user)
      ~assemble
      ~submit
      ~unsubmit
      ~disassemble
      ~format: (Formatters.Set.name' ~link: true)
      ~href: (Endpoints.Page.href_set % Entry.id)
      ~check_product: (fun (set1, access1) (set2, access2) -> Model.Set.equal set1 set2 && Entry.Access.Private.equal access1 access2)
      ?pre_body
  in
  match mode with
  | Create _ | Create_with_local_storage | Quick_create _ ->
    Main_page.assert_can_create_private make_editor
  | Quick_edit _ ->
    (* FIXME: I guess we should be able to check permissions like for Edit. *)
    Main_page.assert_can_create_private make_editor
  | Edit set ->
    let%lwt permission = entry_permission_new set in
    Main_page.assert_can_update permission @@ fun edit_reason ->
    let pre_body =
      match edit_reason with
      | Owner -> []
      | Omniscient_administrator -> [div ~a: [a_class ["mb-4"]] [Alert.make ~level: Warning [txt "You are editing this set as an omniscient administrator."]]]
    in
    make_editor ~pre_body ()

let version_to_name (version : Model.Version.entry) : Version_name.t Lwt.t =
  let%lwt tune = Model.Version.tune' version in
  lwt {
    Version_name.id = Entry.id version;
    name = NEString.to_string @@ NEList.hd @@ Model.Tune.names' tune;
  }

let to_row (set : Model.Set.entry) : Set_row.t Lwt.t =
  let%lwt conceptors = Lwt_list.map_s (Option.get <%> Model.Person.get) @@ Model.Set.conceptors' set in
  let conceptors = List.map Person_editor.to_name conceptors in
  let%lwt tunes = Lwt_list.map_s (Option.get <%> Model.Version.get % fst) @@ Model.Set.contents' set in
  let%lwt tunes = Lwt_list.map_s version_to_name tunes in
  let%lwt permission = entry_permission_new set in
  lwt {
    Set_row.id = Entry.id set;
    name = NEString.to_string @@ Model.Set.name' set;
    kind = Model.Set.kind' set;
    conceptors;
    tunes;
    permission;
  }

let create_row (mode : (Set_row.t, 'a) Editor.mode) =
  let%lwt (mode : (Model.Set.entry, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (fun set -> callback =<< to_row set)
        )
    | Edit result ->
      let%lwt result = Option.get <$> Model.Set.get (Set_row.id result) in
      lwt @@ Editor.Edit result
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt set = Option.get <$> Model.Set.get id in
  create (Edit set)
