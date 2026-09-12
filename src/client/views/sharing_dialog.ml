open Nes
open Utils
open Html
open Dancelor_common
open Model_new
open Search_new
open Components

let copy_link_button ?(object_is_public = false) (id : Any_id.t) =
  Button.make
    ~icon: (Action Share)
    ~classes: ["btn-primary"]
    ~onclick: (fun _ ->
      write_to_clipboard @@ href_any_for_sharing_new id;
      Toast.open_ ~title: "Copied to clipboard" [
        txt "The link to this page was copied to your clipboard.";
        txt (
          if object_is_public then ""
          else
            "This does not guarantee that the recipient has access to the object unless it has also been shared with them."
        );
      ];
      lwt_unit
    )
    ()

let open_ (id : Set_id.t) =
  let%lwt permissions = Madge_client.call_exn Endpoints.Api.(route @@ Set Get_permissions) id in
  let permissions =
    List.map
      (fun (user, role) ->
        (
          Some user,
          (
            (match (role : Permission_new.actor_role) with Owner -> Some 0 | Viewer -> Some 1),
            ((), ((), ()))
          )
        )
      )
      permissions
  in
  let%lwt component =
    Star.make
      ~label: "Actors"
      (
        Cpair.prepare
          ~label: "Actor"
          ~input_group: true
          (
            Selector.prepare
              ~label: "Actor"
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
          )
          (
            let open Plus.Bundle in
            let open Plus.Tuple_elt in
            Plus.prepare
              ~label: "Role"
              ~cast: (function
                | Zero() -> (Owner : Permission_new.actor_role)
                | Succ Zero() -> Viewer
                | _ -> assert false (* types guarantee this is not reachable *)
              )
              ~uncast: (function
                | Owner -> Zero ()
                | Viewer -> one ()
              )
              ~selected_when_empty: 1
              (
                Nil.prepare ~label: "Owner" () ^::
                Nil.prepare ~label: "Viewer" () ^::
                nil
              )
          )
      )
      permissions
  in
  let disabled = S.map Result.is_error @@ Component.signal component in
  let update () =
    let actors = Result.get_ok @@ S.value @@ Component.signal component in
    let actors = List.map (fun (user, role) -> (User_row.id user, role)) actors in
    Madge_client.call_exn Endpoints.Api.(route @@ Set Set_permissions) id actors
  in
  ignore
  <$> Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "Permissions dialog")
      [Component.inner_html component]
      ~buttons: [
        Button.cancel' ~return ();
        Button.make
          ~label: "Update and close"
          ~label_processing: "Updating..."
          ~classes: ["btn-primary"]
          ~disabled
          ~onclick: (fun _ ->
            update ();%lwt
            Toast.open_ ~title: "Permissions updated" [txt "The permissions have been updated."];
            return (some ());
            lwt_unit
          )
          ();
        Button.make
          ~label: "Update and copy link"
          ~label_processing: "Updating..."
          ~icon: (Other Clipboard)
          ~classes: ["btn-primary"]
          ~disabled
          ~onclick: (fun _ ->
            update ();%lwt
            write_to_clipboard @@ href_any_for_sharing_new (Set id);
            Toast.open_ ~title: "Permissions updated" [txt "The permissions have been updated, and a link to this page was copied to your clipboard."];
            return (some ());
            lwt_unit
          )
          ();
      ]

let open_dialog_button (id : Set_id.t) =
  Button.make
    ~icon: (Action Share)
    ~badge: "0+0"
    ~classes: ["btn-primary"]
    ~onclick: (fun _ -> open_ id)
    ()
