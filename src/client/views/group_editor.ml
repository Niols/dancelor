open Nes
open Dancelor_common
open Components
open Utils

let editor =
  let open Bundle in
  group
    ~wrap: (fun (name, (members, ())) -> {Group_form.name; members})
    ~unwrap: (fun {Group_form.name; members} -> (name, (members, ())))
    ~check: Group_form.equal
    (
      Input.prepare_non_empty
        ~type_: Text
        ~label: "Name"
        ~placeholder: "eg. The Dusty Miller"
        () ^::
      Star.prepare
        ~label: "Members"
        (
          Selector.prepare
            ~label: "Member"
            ~search: Api.user_search
            ~id_to_yojson: Id.to_yojson'
            ~id_of_yojson: Id.of_yojson'
            ~serialise: User_row.id
            ~unserialise: (Api.call_or_option @@ User Get_row)
            ~make_descr: (lwt % Username.to_string % User_row.username)
            ~make_result: Tables.user_row
            ~model_name: "user"
            ~create_dialog_content: User_editor.create_row
            ()
        ) ^::
      nil
    )

let submit mode group =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (Group Update) id group;%lwt lwt id
    | _ -> Api.call_exn (Group Create) group
  in
  lwt {With_id.id; form = group}

let unsubmit = lwt % With_id.form

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "group"
    ~icon: (Entity Group)
    ~mode
    editor
    ~format: (Formatters.Group.name ~link: true % With_id.map Group_form.to_name)
    ~href: (Endpoints.Page.href_group % With_id.id)
    ~submit
    ~unsubmit

let create_row (mode : (Group_row.t, 'a) Editor.mode) =
  let%lwt (mode : ((Group_id.t, Group_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map Group_form.to_row)
        )
    | Edit {Group_row.id; _} ->
      let%lwt form = Api.call_exn (Group Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (Group Get_form) id in
  create @@ Edit {With_id.id; form}
