open NesUnix
open Dancelor_common
open Model_new
open Search_new
open Sql_to_row

module User_sql = User_sql.Sqlgg(Sqlgg_postgresql)
module Password_hashed = Fresh.Make(HashedSecret)
module Password_reset_token_hashed = Fresh.Make(HashedSecret)
module Remember_me_key = Fresh.Make(String)
module Remember_me_token_clear = Fresh.Make(String)
module Remember_me_token_hashed = Fresh.Make(HashedSecret)

let get_row_for ids : (User_id.t -> User_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  Utils.fold_to_get_single (User_sql.Fold.get_rows db ~ids) (fun k ~id -> user_sql_to_row ~id ~k: (k id))

let search query : (User_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = ()} = query in
  Connection.with_ @@ fun db ->
  User_sql.List.search
    db
    ~terms
    (fun ~score -> user_sql_to_row ~k: (Pair.snoc score))

(* Legacy *)

type t = Entry.User.t
type entry = t Entry.public

let role_to_common omniscience = function
  | `Normal_user -> Entry.User.Normal_user
  | `Maintainer -> Maintainer
  | `Administrator -> Administrator {omniscience}

let role_of_common = function
  | Entry.User.Normal_user -> (`Normal_user, false)
  | Maintainer -> (`Maintainer, false)
  | Administrator {omniscience} -> (`Administrator, omniscience)

let row_to_user
    ~id
    ~username
    ~role
    ~omniscience
    ~github_handle
    ~created_at
    ~modified_at
  =
  Entry.make
    ~id
    ~meta: (Entry.Meta.make ~created_at ~modified_at ())
    ~access: Entry.Access.Public
    (
      Entry.User.make
        ~username: (Username.of_string_exn username)
        ~role: (role_to_common omniscience role)
        ~github_handle
        ()
    )

let get id : entry option Lwt.t =
  Connection.with_ @@ fun db ->
  User_sql.Single.get db ~id (row_to_user ~id)

let get_from_username username =
  let username = Username.to_string username in
  Connection.with_ @@ fun db ->
  User_sql.Single.get_from_username db ~username (row_to_user ~username)

let get_all () : entry list Lwt.t =
  Connection.with_ @@ fun db ->
  User_sql.List.get_all db row_to_user

let get_password_from_username username =
  let username = Username.to_string username in
  Connection.with_ @@ fun db ->
  Option.join
  <$> User_sql.Single.get_password_from_username db ~username (fun ~password ->
      Option.map (Password_hashed.inject % HashedSecret.unsafe_of_string) password
    )

let get_password_reset_token_from_username username =
  let username = Username.to_string username in
  Connection.with_ @@ fun db ->
  Option.join
  <$> User_sql.Single.get_password_reset_token_from_username db ~username (fun ~password_reset_token_hash ~password_reset_token_max_date ->
      Option.bind password_reset_token_hash @@ fun password_reset_token_hash ->
      Option.bind password_reset_token_max_date @@ fun password_reset_token_max_date ->
      Some (
        (Password_reset_token_hashed.inject @@ HashedSecret.unsafe_of_string password_reset_token_hash),
        password_reset_token_max_date
      )
    )

let create ~username ~role ~github_handle ~password_reset_token_hash ~password_reset_token_max_date =
  let (role, omniscience) = role_of_common role in
  Connection.with_ @@ fun db ->
  let%lwt id = Entry_new.make_public db `User in
  let%lwt _ =
    User_sql.create
      db
      ~id
      ~username: (Username.to_string username)
      ~role
      ~omniscience
      ~github_handle
      ~password_reset_token_hash: (some @@ HashedSecret.unsafe_to_string @@ Password_reset_token_hashed.project password_reset_token_hash)
      ~password_reset_token_max_date: (Some password_reset_token_max_date)
  in
  lwt id

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
      ~key: (Remember_me_key.project key)

let set_password_reset_token id password_reset_token_hash password_reset_token_max_date =
  Connection.with_ @@ fun db ->
  ignore <$> remove_all_remember_me_tokens id;%lwt
  ignore
  <$> User_sql.set_password_reset_token
      db
      ~id
      ~password_reset_token_hash: (Some (HashedSecret.unsafe_to_string @@ Password_reset_token_hashed.project password_reset_token_hash))
      ~password_reset_token_max_date: (Some password_reset_token_max_date)

let set_password id password =
  Connection.with_ @@ fun db ->
  ignore <$> remove_all_remember_me_tokens id;%lwt
  ignore
  <$> User_sql.set_password
      db
      ~id
      ~password: (some @@ HashedSecret.unsafe_to_string @@ Password_hashed.project password)

let find_remember_me_token user_id key =
  Connection.with_ @@ fun db ->
  User_sql.Single.find_remember_me_token
    db
    ~user_id
    ~key: (Remember_me_key.project key)
    (fun ~hash ~max_date -> (Remember_me_token_hashed.inject @@ HashedSecret.unsafe_of_string hash, max_date))

let add_remember_me_token user_id key hash max_date =
  Connection.with_ @@ fun db ->
  ignore
  <$> User_sql.add_remember_me_token
      db
      ~user_id
      ~key: (Remember_me_key.project key)
      ~hash: (HashedSecret.unsafe_to_string @@ Remember_me_token_hashed.project hash)
      ~max_date

let set_omniscience id value =
  Connection.with_ @@ fun db ->
  ignore <$> User_sql.set_omniscience db ~id ~omniscience: value
