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

let component =
  Bundle.pair
    ~wrap: (fun (entry_is_public, actor_roles) -> {Permissions_form.entry_is_public; actor_roles})
    ~unwrap: (fun {Permissions_form.entry_is_public; actor_roles} -> (entry_is_public, actor_roles))
    (
      Choices.prepare_radios
        ~label: "Is public"
        [
          Choices.choice ~value: true [txt "Public"] ~checked: true;
          Choices.choice ~value: false [txt "Private"];
        ]
    )
    (
      Star.prepare
        ~label: "Actors"
        (
          let open Bundle in
          pair
            ~label: "Actor"
            ~stacking: Horizontal
            ~wrap: Fun.id
            ~unwrap: Fun.id
            (
              Selector.prepare
                ~label: "Actor"
                ~model_name: "user"
                ~make_descr: (fun user -> lwt @@ Username.to_string user.User_row.username)
                ~make_result: (Any_result_new.make_user_result ?in_search: None)
                ~results_when_no_search: (Option.to_list % Option.map Actor.to_user_row <$> Environment.actor)
                ~search: (fun slice input ->
                  match User_query.parse input with
                  | Error msg -> lwt_error msg
                  | Ok query -> ok <$> Api.call_exn (User Search) slice query
                )
                ~id_to_yojson: Entry.Id.to_yojson'
                ~id_of_yojson: Entry.Id.of_yojson'
                ~serialise: User_row.id
                ~unserialise: (Api.call_or_option @@ User Get_row)
                ()
            )
            (
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
                  let open Plus.Bundle in
                  Nil.prepare ~label: "Owner" () ^::
                  Nil.prepare ~label: "Viewer" () ^::
                  nil
                )
            )
        )
    )

let open_ (id : Any_id.t) (permissions : Permissions_form.t) =
  let component_state =
    (* FIXME: OMG it is so hackish to have to make a state by hand?! *)
    let is_public_state =
      match permissions.entry_is_public with
      | true -> [true; false]
      | false -> [false; true]
    in
    let actor_roles_state =
      List.map
        (fun (user, role) ->
          (
            Some user.User_row.id,
            (
              (
                (match (role : Permission_new.actor_role) with Owner -> Some 0 | Viewer -> Some 1),
                ((), ((), ()))
              ),
              ()
            )
          )
        )
        permissions.actor_roles
    in
      (is_public_state, (actor_roles_state, ()))
  in
  let%lwt component = Component.initialise component component_state in
  let disabled = S.map Result.is_error @@ Component.signal component in
  let update () =
    let permissions = Result.get_ok @@ S.value @@ Component.signal component in
    Api.call_exn (Any Set_permissions) (Any_id.to_entry_id id) permissions
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
            write_to_clipboard @@ href_any_for_sharing_new id;
            Toast.open_ ~title: "Permissions updated" [txt "The permissions have been updated, and a link to this page was copied to your clipboard."];
            return (some ());
            lwt_unit
          )
          ();
      ]

let open_dialog_button id =
  R.div (
    S.from_lwt
      [Button.make
        ~classes: ["btn-primary"; "placeholder"]
        ~icon: (Action Share)
        ~badge: "0"
        ~disabled: (S.const true)
        ();
      ]
      (
        let%lwt permissions = Api.call_exn (Any Get_permissions) (Any_id.to_entry_id id) in
        let%lwt actor_id = Environment.actor_id in
        let badge =
          if permissions.entry_is_public then
            "∞"
          else
            let other_actors =
              List.filter
                (fun ({User_row.id = actor_id'; _}, _) ->
                  not @@ Option.equal Entry.Id.equal' (Some actor_id') actor_id
                )
                permissions.actor_roles
            in
            string_of_int (List.length other_actors)
        in
        lwt [
          Button.make
            ~icon: (Action Share)
            ~badge
            ~classes: ["btn-primary"]
            ~onclick: (fun _ -> open_ id permissions)
            ();
        ]
      )
  )
