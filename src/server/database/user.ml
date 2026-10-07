open Nes_unix
open Dancelor_common
open Sql_to_row
open Sql_to_view
open Sql_to_form

module User_sql = User_sql.Sqlgg(Sqlgg_postgresql)

let get_row_for ids : (User_id.t -> User_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  Utils.fold_to_get_single (User_sql.Fold.get_rows db ~ids) (fun k ~id -> user_sql_to_row ~id ~k: (k id))

let get_row id =
  (fun f -> f id) <$> get_row_for [id]

let get_view id : User_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  User_sql.Single.get_view db ~id (user_sql_to_view ~id ~k: Fun.id)

let get_form id : User_form.t option Lwt.t =
  Connection.with_ @@ fun db ->
  User_sql.Single.get_form db ~id (user_sql_to_form ~id ~k: Fun.id)

let search query : (User_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = ()} = query in
  Connection.with_ @@ fun db ->
  User_sql.List.search
    db
    ~terms
    (fun ~score -> user_sql_to_row ~k: (Pair.snoc score))

let get_actor_gen f =
  Connection.with_ @@ fun db ->
  match%lwt f db with
  | None -> lwt_none
  | Some (id, username, github_handle, role, omniscience, person_id, person_name) ->
    lwt_some {
      Actor.id;
      username = Username.of_string_exn username;
      github_handle;
      role;
      omniscience;
      person =
      match person_id, person_name with
      | None, None -> None
      | Some id, Some name -> Some {Person_row.id; name};
      | _ -> assert false
    }

let get_actor id =
  get_actor_gen (fun db -> User_sql.get_actor db ~id)

let get_actor_from_username username =
  get_actor_gen (fun db -> User_sql.get_actor_from_username db ~username: (Username.to_string username))

(* Legacy *)

let get_password_from_username username =
  let username = Username.to_string username in
  Connection.with_ @@ fun db ->
  Option.join
  <$> User_sql.Single.get_password_from_username db ~username (fun ~password -> password)

let get_password_reset_token_from_username username =
  let username = Username.to_string username in
  Connection.with_ @@ fun db ->
  Option.join
  <$> User_sql.Single.get_password_reset_token_from_username db ~username (fun ~password_reset_token_hash ~password_reset_token_max_date ->
      Option.bind password_reset_token_hash @@ fun password_reset_token_hash ->
      Option.bind password_reset_token_max_date @@ fun password_reset_token_max_date ->
      Some (password_reset_token_hash, password_reset_token_max_date)
    )

let create {User_form.username; email} ~password_reset_token_hash ~password_reset_token_max_date =
  Connection.with_ @@ fun db ->
  let%lwt id = Entity.make_public db `User in
  ignore
  <$> User_sql.create
      db
      ~id
      ~username: (Username.to_string username)
      ~email
      ~password_reset_token_hash: (Some password_reset_token_hash)
      ~password_reset_token_max_date: (Some password_reset_token_max_date);%lwt
  lwt id

let update id {User_form.username; email} =
  Connection.with_ @@ fun db ->
  ignore
  <$> User_sql.update
      db
      ~id
      ~username: (Username.to_string username)
      ~email

let remove_all_remember_me_tokens user_id =
  Connection.with_ @@ fun db ->
  (* FIXME: an index covering user_id *)
  ignore
  <$> User_sql.remove_all_remember_me_tokens db ~user_id

let remove_one_remember_me_token user_id key =
  Connection.with_ @@ fun db ->
  ignore
  <$> User_sql.remove_one_remember_me_token
      db
      ~user_id
      ~key

let set_password_reset_token id password_reset_token_hash password_reset_token_max_date =
  Connection.with_ @@ fun db ->
  ignore <$> remove_all_remember_me_tokens id;%lwt
  ignore
  <$> User_sql.set_password_reset_token
      db
      ~id
      ~password_reset_token_hash: (Some password_reset_token_hash)
      ~password_reset_token_max_date: (Some password_reset_token_max_date)

let set_password id password =
  Connection.with_ @@ fun db ->
  ignore <$> remove_all_remember_me_tokens id;%lwt
  ignore <$> User_sql.set_password db ~id ~password: (Some password)

let find_remember_me_token user_id key =
  Connection.with_ @@ fun db ->
  User_sql.Single.find_remember_me_token
    db
    ~user_id
    ~key
    (fun ~hash ~max_date -> (hash, max_date))

let add_remember_me_token user_id key hash max_date =
  Connection.with_ @@ fun db ->
  ignore <$> User_sql.add_remember_me_token db ~user_id ~key ~hash ~max_date

let set_omniscience id value =
  Connection.with_ @@ fun db ->
  ignore <$> User_sql.set_omniscience db ~id ~omniscience: value
