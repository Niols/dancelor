open Nes
open Dancelor_common
open Model_new
open Components
open Html
open Utils

let (show_preview, set_show_preview) = S.create false
let flip_show_preview () = set_show_preview (not (S.value show_preview))

let editor =
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
        ~search: Api.person_search
        ~id_to_yojson: Entry.Id.to_yojson'
        ~id_of_yojson: Entry.Id.of_yojson'
        ~serialise: Person_row.id
        ~unserialise: (Api.call_or_option @@ Person Get_row)
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
            ~search: Api.version_search
            ~id_to_yojson: Entry.Id.to_yojson'
            ~id_of_yojson: Entry.Id.of_yojson'
            ~serialise: Version_row.id
            ~unserialise: (Api.call_or_option @@ Version Get_row)
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
  nil

let assemble (name, (kind, (conceptors, (contents, (order, ()))))) =
  {Set_form.name; kind; conceptors; contents; order}

let disassemble {Set_form.name; kind; conceptors; contents; order} =
  lwt (name, (kind, (conceptors, (contents, (order, ())))))

let submit mode set =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Set Update) id set;%lwt lwt id
    | _ -> Api.call_exn (Set Create) set
  in
  lwt {With_id.id; form = set}

let unsubmit = lwt % With_id.form

let entry_permission_new entry =
  let access = Entry.access entry in
  let entry_is_public = Entry.Access.Private.is_public access in
  let%lwt actor_role, actor_is_omniscient_administrator =
    match%lwt Environment.actor with
    | None -> lwt (None, false)
    | Some actor ->
      lwt (
        (
          if List.exists (Entry.Id.equal' (Entry.id actor)) (Entry.Access.Private.owners access) then
            Some (Owner : Permission_new.actor_role)
          else if List.exists (Entry.Id.equal' (Entry.id actor)) (Entry.Access.Private.viewers access) then
            Some (Viewer : Permission_new.actor_role)
          else
            None
        ),
        Model.User.is_omniscient_administrator' actor
      )
  in
  lwt @@ Permission_new.make ~entry_is_public ~actor_role ~actor_is_omniscient_administrator

let create mode =
  (* FIXME: if [mode] is an edition, then we should [assert_can_update_public] *)
  (* FIXME: reintroduce the [?pre_body] explaining why the actor is allowed to
     edit; maybe just via a helper [assert_can_create_private]? *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "set"
    ~icon: (Model Set)
    ~mode
    editor
    ~assemble
    ~submit
    ~unsubmit
    ~disassemble
    ~format: (Formatters_new.Set.name ~link: true % With_id.map Set_form.to_name)
    ~href: (Endpoints.Page.href_set % With_id.id)
    ~check_product: Set_form.equal

(* match mode with *)
(* | Create _ | Create_with_local_storage | Quick_create _ -> *)
(*   Main_page.assert_can_create_private make_editor *)
(* | Quick_edit _ -> *)
(*   (\* FIXME: I guess we should be able to check permissions like for Edit. *\) *)
(*   Main_page.assert_can_create_private make_editor *)
(* | Edit set -> *)
(*   let%lwt permission = entry_permission_new set in *)
(*   Main_page.assert_can_update permission @@ fun edit_reason -> *)
(*   let pre_body = *)
(*     match edit_reason with *)
(*     | Owner -> [] *)
(*     | Omniscient_administrator -> [div ~a: [a_class ["mb-4"]] [Alert.make ~level: Warning [txt "You are editing this set as an omniscient administrator."]]] *)
(*   in *)
(*   make_editor ~pre_body () *)

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
  let%lwt (mode : ((Set_id.t, Set_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map Set_form.to_row)
        )
    | Edit {Set_row.id; _} ->
      let%lwt form = Api.call_exn (Set Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (Set Get_form) id in
  create @@ Edit {With_id.id; form}
