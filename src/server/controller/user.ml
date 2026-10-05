open NesUnix
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.user": Logs.LOG)

(* FIXME: Move this controller to use [Shared]. This will require introducing
   proper models for users and such, which we have been planning to do for a
   long time. *)

let get_row_for _env ids =
  Database.User.get_row_for ids

let get_row env id =
  match%lwt (fun f -> f id) <$> get_row_for env [id] with
  | None -> Shared.reject_can_get ()
  | Some row -> lwt row

let get_rows env ids =
  let%lwt row_for = get_row_for env ids in
  lwt @@ List.filter_map row_for ids

let cache : (Environment.cache_key * User_query.t, (User_row.t * float) Search_result.t Lwt.t) Cache.t =
  Cache.create ~lifetime: 60 ()

let search' env query =
  Cache.use ~cache ~key: (Environment.cache_key env, query) @@ fun () ->
  let%lwt items = Database.User.search query in
  lwt {Search_result.total = List.length items; items}

let search env slice query =
  let%lwt {total; items} = search' env query in
  let items = List.map fst @@ Slice.list ~strict: false slice items in
  lwt {Search_result.total; items}

let status env =
  lwt @@
    match Environment.actor env with
    | Anonymous -> None
    | Signed_in actor -> Some actor

(* Legacy *)

let sign_in env username password remember_me =
  Log.info (fun m -> m "Attempt to sign in with username `%s`." (Username.to_string username));
  match Environment.actor env with
  | Signed_in _actor ->
    Log.info (fun m -> m "Rejecting because already signed in.");
    lwt_none
  | Anonymous ->
    (* FIXME: should be included in [get_password_from_username] except we return a user  *)
    match%lwt Database.User.get_actor_from_username username with
    | None ->
      Log.info (fun m -> m "Rejecting because of wrong username.");
      lwt_none
    | Some actor ->
      match%lwt Database.User.get_password_from_username username with
      | None ->
        Log.info (fun m -> m "Rejecting because user has no password.");
        lwt_none
      | Some hashedPassword when not @@ HashedSecret.is ~clear: (Password_clear.project password) (Database.Password_hash.project hashedPassword) ->
        (* NOTE: Similar to other tokens, we should be able to compare directly but need to project. *)
        Log.info (fun m -> m "Rejecting because passwords do not match.");
        lwt_none
      | Some _ ->
        Environment.sign_in env actor ~remember_me;%lwt
        Log.info (fun m -> m "Accepted sign in for %a." Environment.pp env);
        lwt_some actor

let sign_out env =
  match Environment.actor env with
  | Anonymous -> lwt_unit
  | Signed_in actor -> Environment.sign_out env actor

let create env (user : User_create_form.t) =
  Shared.assert_can_administrate env @@ fun _admin ->
  let token = Password_reset_token_clear.make () in
  (* NOTE: We should use Password_reset_token_hashed.make here, but HashedSecret.make
     is only available on the server side (NesHashedSecretUnix), not in common code. *)
  let password_reset_token_hash = Database.Password_reset_token_hash.inject @@ HashedSecret.make ~clear: (Password_reset_token_clear.project token) in
  let password_reset_token_max_date = Datetime.make_in_the_future (float_of_int @@ 3 * 24 * 3600) in
  let%lwt id =
    Database.User.create
      ~username: user.username
      ~email: user.email
      ~password_reset_token_hash
      ~password_reset_token_max_date
  in
  let%lwt user = Option.get <$> Database.User.get_row id in
  lwt (user, token)

let prepare_reset_password env username =
  Shared.assert_can_administrate env @@ fun _admin ->
  Log.info (fun m -> m "Preparing password reset for user `%s`." (Username.to_string username));
  match%lwt Database.User.get_actor_from_username username with
  | None ->
    Log.info (fun m -> m "Rejecting because username not found.");
    Madge_server.shortcut_bad_request "User not found."
  | Some actor ->
    let token = Password_reset_token_clear.make () in
    (* NOTE: We should use Password_reset_token_hashed.make here, but HashedSecret.make
       is only available on the server side (NesHashedSecretUnix), not in common code. *)
    let hashed_token = Database.Password_reset_token_hash.inject @@ HashedSecret.make ~clear: (Password_reset_token_clear.project token) in
    let max_date = Datetime.make_in_the_future (float_of_int @@ 3 * 24 * 3600) in
    Database.User.set_password_reset_token actor.id hashed_token max_date;%lwt
    Log.info (fun m -> m "Password reset token generated for user `%s`." (Username.to_string username));
    lwt token

let reset_password username token password =
  Log.info (fun m -> m "Attempt to reset password for user `%s`." (Username.to_string username));
  (* FIXME: should be included in [get_password_reset_token_from_username] except we return a user  *)
  match%lwt Database.User.get_actor_from_username username with
  | None ->
    Log.info (fun m -> m "Rejecting because of wrong username.");
    Madge_server.shortcut_forbidden_no_leak ()
  | Some actor ->
    match%lwt Database.User.get_password_reset_token_from_username username with
    | None ->
      Log.info (fun m -> m "Rejecting because of lack of token.");
      Madge_server.shortcut_forbidden_no_leak ()
    | Some (_, token_date) when Datetime.(diff (now ())) token_date > 3. *. 24. *. 3600. ->
      Log.info (fun m -> m "Rejecting because token is too old.");
      Madge_server.shortcut_forbidden_no_leak ()
    | Some (hashed_token, _) ->
      (* NOTE: We should be able to compare Password_reset_token_clear with
         Password_reset_token_hashed directly, but we need to project because
         HashedSecret.is is only available on the server side. *)
      if not @@ HashedSecret.is ~clear: (Password_reset_token_clear.project token) (Database.Password_reset_token_hash.project hashed_token) then
        (
          Log.info (fun m -> m "Rejecting because tokens do no match.");
          Madge_server.shortcut_forbidden_no_leak ()
        )
      else
        (
          Log.info (fun m -> m "Accepting to reset password.");
          (* NOTE: We should use Password_hashed.make here, but HashedSecret.make
             is only available on the server side (NesHashedSecretUnix), not in common code. *)
          let password = Database.Password_hash.inject @@ HashedSecret.make ~clear: (Password_clear.project password) in
          Database.User.set_password actor.id password
        )

let set_omniscience env value =
  Shared.assert_can_administrate env @@ fun actor ->
  Database.User.set_omniscience actor.id value

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.User.t -> a = fun env endpoint ->
  match endpoint with
  | Get_row -> get_row env
  | Status -> status env
  | Sign_in -> sign_in env
  | Sign_out -> sign_out env
  | Create -> create env
  | Prepare_reset_password -> prepare_reset_password env
  | Reset_password -> reset_password
  | Search -> search env
  | Set_omniscience -> set_omniscience env
