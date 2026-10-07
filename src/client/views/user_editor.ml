open Nes
open Dancelor_common
open Components
open Html

let editor =
  let open Bundle in
  group
    ~wrap: (fun (username, (email, ())) -> {User_form.username; email})
    ~unwrap: (fun {User_form.username; email} -> (username, (email, ())))
    ~check: User_form.equal
    (
      Input.prepare
        ~type_: Text
        ~placeholder: "JeanMilligan"
        ~label: "Username"
        ~serialise: Username.to_string
        ~validate: (S.const % Option.to_result ~none: "Invalid username format." % Username.from_string)
        () ^::
      Input.prepare
        ~type_: Text
        ~placeholder: "millijean1923@rscds.org"
        ~label: "Email"
        ~serialise: Email.to_string
        ~validate: (S.const % Option.to_result ~none: "Invalid email format." % Email.of_string)
        () ^::
      nil
    )

let submit mode user =
  let%lwt id =
    match mode with
    | Editor.Edit {With_id.id; _} -> Api.call_exn (User Update) id user;%lwt lwt id
    | _ -> assert false
  in
  lwt {With_id.id; form = user}

let unsubmit = lwt % With_id.form

let create mode =
  (* FIXME: if [mode] is an edition, then we should assert_can_update_public *)
  Main_page.assert_can_create_public @@ fun () ->
  Editor.make_page
    ~key: "user"
    ~icon: (Entity User)
    editor
    ~mode
    ~submit
    ~unsubmit
    ~format: (Formatters.User.username ~link: true % With_id.map User_form.to_name)
    ~href: (Endpoints.Page.href_user % With_id.id)

let create_row (mode : (User_row.t, 'a) Editor.mode) =
  let%lwt (mode : ((User_id.t, User_form.t) With_id.t, 'a) Editor.mode) =
    match mode with
    | Create state -> lwt @@ Editor.Create state
    | Create_with_local_storage -> lwt Editor.Create_with_local_storage
    | Quick_create (init, callback) ->
      lwt @@
        Editor.Quick_create (
          init,
          (callback % With_id.map User_form.to_row)
        )
    | Edit {User_row.id; _} ->
      let%lwt form = Api.call_exn (User Get_form) id in
      lwt @@ Editor.Edit {With_id.id; form}
    | Quick_edit state -> lwt @@ Editor.Quick_edit state
  in
  create mode

let add () =
  create Create_with_local_storage

let edit id =
  let%lwt form = Api.call_exn (User Get_form) id in
  create @@ Edit {With_id.id; form}
