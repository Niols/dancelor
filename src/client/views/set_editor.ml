open Nes
open Dancelor_common
open Components
open Html
open Utils

let (show_preview, set_show_preview) = S.create false
let flip_show_preview () = set_show_preview (not (S.value show_preview))

let editor =
  let open Bundle in
  group
    ~wrap: (fun (name, (kind, (conceptors, (contents, (order, ()))))) ->
      {Set_form.name; kind; conceptors; contents; order}
    )
    ~unwrap: (fun {Set_form.name; kind; conceptors; contents; order} ->
      (name, (kind, (conceptors, (contents, (order, ())))))
    )
    ~check: Set_form.equal
    (
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
            ~make_result: (Any_result.make_person_result ?in_search: None)
            ~results_when_no_search: (Option.to_list <$> Environment.person)
            ~label: "Conceptor"
            ~model_name: "person"
            ~create_dialog_content: Person_editor.create_row
            ~search: Api.person_search
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
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
                ~make_result: (Any_result.make_version_result ?in_search: None)
                ~make_more_results: (fun version ->
                  S.flip_map show_preview @@ function
                    | true -> [tr [td ~a: [a_colspan 9999] [Version_snippets.make ~show_audio: false (Version_row.to_name version)]]]
                    | false -> []
                )
                ~label: "Version"
                ~model_name: "version"
                ~create_dialog_content: Version_editor.create_row
                ~search: Api.version_search
                ~id_to_yojson: Id.to_yojson'
                ~id_of_yojson: Id.of_yojson'
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
        ~serialise: Set_order.to_string
        ~validate: (S.const % Option.to_result ~none: "Not a valid order." % Set_order.of_string_opt)
        () ^::
      nil
    )

let submit mode set =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Set Update) id set;%lwt lwt id
    | _ -> Api.call_exn (Set Create) set
  in
  lwt {With_id.id; form = set}

let unsubmit = lwt % With_id.form

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
    ~submit
    ~unsubmit
    ~format: (Formatters.Set.name ~link: true % With_id.map Set_form.to_name)
    ~href: (Endpoints.Page.href_set % With_id.id)

(* match mode with *)
(* | Create _ | Create_with_local_storage | Quick_create _ -> *)
(*   Main_page.assert_can_create_private make_editor *)
(* | Quick_edit _ -> *)
(*   (\* FIXME: I guess we should be able to check permissions like for Edit. *\) *)
(*   Main_page.assert_can_create_private make_editor *)
(* | Edit set -> *)
(*   let%lwt permission = entry_permission set in *)
(*   Main_page.assert_can_update permission @@ fun edit_reason -> *)
(*   let pre_body = *)
(*     match edit_reason with *)
(*     | Owner -> [] *)
(*     | Omniscient_administrator -> [div ~a: [a_class ["mb-4"]] [Alert.make ~level: Warning [txt "You are editing this set as an omniscient administrator."]]] *)
(*   in *)
(*   make_editor ~pre_body () *)

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
