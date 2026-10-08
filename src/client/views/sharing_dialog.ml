open Nes
open Utils
open Html
open Dancelor_common
open Components

let copy_link_button ?(object_is_public = false) (id : Entity_id.t) =
  Button.make
    ~icon: (Action Share)
    ~classes: ["btn-primary"]
    ~onclick: (fun _ ->
      write_to_clipboard @@ href_entity_for_sharing id;
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
    ~wrap: (fun (entity_is_public, actor_roles) -> {Permissions_form.entity_is_public; actor_roles})
    ~unwrap: (fun {Permissions_form.entity_is_public; actor_roles} -> (entity_is_public, actor_roles))
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
                ~make_descr: (function
                  | `User user -> lwt @@ ((^) "User ") @@ Username.to_string user.User_row.username
                  | `Group group -> lwt @@ ((^) "Group ") @@ group.Group_row.name
                )
                ~make_result: (Tables.entity_row ?in_search: None)
                ~results_when_no_search: (List.map Principal_row.user % Option.to_list % Option.map Actor.to_user_row <$> Environment.actor)
                ~search: (fun slice input ->
                  match Principal_query.parse input with
                  | Error msg -> lwt_error msg
                  | Ok query -> ok <$> Api.call_exn (Entity Search_principals) slice query
                )
                ~id_to_yojson: Principal_id.to_yojson
                ~id_of_yojson: Principal_id.of_yojson
                ~serialise: Principal_row.to_id
                ~unserialise: (Api.call_or_option @@ Entity Principal_row)
                ()
            )
            (
              let open Plus.Tuple_elt in
              Plus.prepare
                ~label: "Role"
                ~cast: (function
                  | Zero() -> (Owner : Permission.actor_role)
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

let open_ (id : Entity_id.t) (permissions : Permissions_form.t) : Permissions_form.t option Lwt.t =
  let component_state =
    (* FIXME: OMG it is so hackish to have to make a state by hand?! *)
    let is_public_state =
      match permissions.entity_is_public with
      | true -> [true; false]
      | false -> [false; true]
    in
    let actor_roles_state =
      List.map
        (fun (principal, role) ->
          (
            Some (Principal_row.to_id principal),
            (
              (
                (match (role : Permission.actor_role) with Owner -> Some 0 | Viewer -> Some 1),
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
    Api.call_exn (Entity Set_permissions) (Entity_id.to_untagged id) permissions;%lwt
    lwt permissions
  in
  Page.open_dialog @@ fun return ->
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
          let%lwt permissions = update () in
          Toast.open_ ~title: "Permissions updated" [txt "The permissions have been updated."];
          return (Some permissions);
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
          let%lwt permissions = update () in
          write_to_clipboard @@ href_entity_for_sharing id;
          Toast.open_ ~title: "Permissions updated" [txt "The permissions have been updated, and a link to this page was copied to your clipboard."];
          return (Some permissions);
          lwt_unit
        )
        ();
    ]

let open_dialog_button id =
  R.div (
    let (permissions_signal, update_permissions_signal) = S.create None in
    let update_permissions_signal = update_permissions_signal % some in
    Lwt.async (fun () -> update_permissions_signal <$> Api.call_exn (Entity Get_permissions) (Entity_id.to_untagged id));
    S.map
      (function
        | None, _ | _, None ->
          [
            Button.make
              ~classes: ["btn-primary"; "placeholder"]
              ~icon: (Action Share)
              ~badge: "0"
              ~disabled: (S.const true)
              ();
          ]
        | Some actor_id, Some(permissions : Permissions_form.t) ->
          let badge =
            if permissions.entity_is_public then
              "∞"
            else
              let other_actors =
                List.filter
                  (function
                    | (`User {User_row.id = actor_id'; _}, _) when Option.equal Id.equal' (Some actor_id') actor_id -> false
                    | _ -> true
                  )
                  permissions.actor_roles
              in
              string_of_int (List.length other_actors)
          in
          [
            Button.make
              ~icon: (Action Share)
              ~badge
              ~classes: ["btn-primary"]
              ~onclick: (fun _ ->
                let%lwt new_permissions = open_ id permissions in
                Option.iter update_permissions_signal new_permissions;
                lwt_unit
              )
              ();
          ]
      )
      (S.l2 Pair.cons Environment.actor_id_s permissions_signal)
  )
