open Nes
open Dancelor_common
open Html
open Utils

let view id =
  Main_page.madge_call_or_404 (User Get_view) id @@ fun user ->
  Page.make'
    ~parent_title: "User"
    ~title: (lwt @@ Username.to_string user.username)
    ~actions: [
      (
        match%lwt Environment.actor with
        | None -> lwt_nil
        | Some actor ->
          match User_id.equal actor.id id || actor.role = Administrator with
          | false -> lwt_nil
          | true ->
            lwt [
              Button.make_a
                ~label: "Edit"
                ~icon: (Action Edit)
                ~href: (S.const @@ Endpoints.Page.(href @@ User Edit) id)
                ~dropdown: true
                ();
            ]
      );
    ]
    [
      div [
        txtf "Joined %s" @@ Datetime.to_string user.joined
      ];
    ]
