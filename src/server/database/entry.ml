open Nes
open Dancelor_common
open Sql_to_row

module Entry_sql = Entry_sql.Sqlgg(Sqlgg_postgresql)

type type_ = [
  | `Book
  | `Dance
  | `Person
  | `Set
  | `Source
  | `Tune
  | `User
  | `Version
]

type visibility = [
  | `Owners_only
  | `Everyone
  | `Select_viewers
]

type visibility_or_public = [visibility | `Public]

let classify_type : type_ -> [`Public | `Private] = function
  | `Dance | `Person | `Source | `Tune | `User | `Version -> `Public
  | `Set | `Book -> `Private

(** Handles only the insertion into the ["entry"] table. In
    particular, this function does not handle the ["entry_viewers"]
    and ["entry_owners"] tables; see {!insert_or_update_private}. *)
let insert_to_entry_table db ~is_public type_ =
  let rec make () =
    let id = Id.make () in
    match%lwt Entry_sql.get_type_unsafe db ~id with
    | None ->
      let%lwt _ = Entry_sql.register db ~id ~type_ ~is_public in
      lwt @@ Id.unsafe_coerce id
    | Some _ ->
      make () (* extremely unlikely *)
  in make ()

(** Takes a function [f] that handles inserting/updating to the
    ["entry"] table and handles everything else that has to do with
    private access. *)
let insert_or_update_private db ~viewers ~owners f =
  let%lwt id = f () in
  ignore <$> Entry_sql.delete_all_actors db ~entry_id: id;%lwt
  Lwt_list.iter_s
    (fun viewer ->
      ignore
      <$> Entry_sql.add_one_actor
          db
          ~entry_id: id
          ~user_id: viewer
          ~role: `Viewer
    )
    viewers;%lwt
  Lwt_list.iter_s
    (fun owner ->
      ignore
      <$> Entry_sql.add_one_actor
          db
          ~entry_id: id
          ~user_id: owner
          ~role: `Owner
    )
    owners;%lwt
  lwt @@ Id.unsafe_coerce id

let make_public db type_ =
  assert (classify_type type_ = `Public);
  (* Public objects only need the ["entry"] table in which they have
     no visibility field. *)
  insert_to_entry_table db type_ ~is_public: true

let make_private_new db type_ owner =
  assert (classify_type type_ = `Private);
  insert_or_update_private db ~viewers: [] ~owners: [owner] @@ fun () ->
  insert_to_entry_table db type_ ~is_public: false

let touch db id =
  ignore <$> Entry_sql.touch db ~id: (Id.unsafe_coerce id)

let delete db id =
  let id = Id.unsafe_coerce id in
  ignore <$> Entry_sql.delete_all_actors db ~entry_id: id;%lwt
  ignore <$> Entry_sql.delete db ~id

let get_newest ~actor_id ~limit =
  assert (limit <= 1000);
  Connection.with_ @@ fun db ->
  (* FIXME: some gymnastics just because users aren't handled so well yet *)
  let%lwt newest =
    Entry_sql.List.get_newest db ~actor_id ~limit: (Int64.of_int limit) (fun ~id ~type_ ->
      some @@
        match type_ with
        | `Book -> Any_id.book @@ Id.unsafe_coerce id
        | `Dance -> Any_id.dance @@ Id.unsafe_coerce id
        | `Person -> Any_id.person @@ Id.unsafe_coerce id
        | `Set -> Any_id.set @@ Id.unsafe_coerce id
        | `Source -> Any_id.source @@ Id.unsafe_coerce id
        | `Tune -> Any_id.tune @@ Id.unsafe_coerce id
        | `User -> Any_id.user @@ Id.unsafe_coerce id
        | `Version -> Any_id.version @@ Id.unsafe_coerce id
    )
  in
  lwt @@ List.filter_map Fun.id newest

let get_permission db ~actor_id id =
  let id = Id.unsafe_coerce id in
  Option.map
    (fun (entry_is_public, actor_role, actor_is_omniscient_administrator) ->
      {
        Permission.entry_is_public;
        actor_role = Option.map Sql_types.actor_role_to_common actor_role;
        actor_is_omniscient_administrator;
      }
    )
  <$> Entry_sql.get_permission db ~actor_id ~id

let get_actor_roles db id =
  let id = Id.unsafe_coerce id in
  Entry_sql.List.get_actor_roles db ~entry_id: id (fun ~role ->
    user_sql_to_row ~k: (fun actor -> (actor, Sql_types.actor_role_to_common role))
  )

let set_is_public db id is_public =
  let id = Id.unsafe_coerce id in
  ignore <$> Entry_sql.set_is_public db ~id ~is_public

let set_actor_roles db id actor_roles =
  let id = Id.unsafe_coerce id in
  ignore <$> Entry_sql.delete_all_actors db ~entry_id: id;%lwt
  Lwt_list.iter_s
    (fun ({User_row.id = user_id; _}, role) ->
      ignore <$> Entry_sql.add_one_actor db ~entry_id: id ~user_id ~role: (Sql_types.actor_role_of_common role)
    )
    actor_roles
