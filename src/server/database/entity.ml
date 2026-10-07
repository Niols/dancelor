open Nes
open Dancelor_common
open Sql_to_row

module Entity_sql = Entity_sql.Sqlgg(Sqlgg_postgresql)

type visibility = [
  | `Owners_only
  | `Everyone
  | `Select_viewers
]

type visibility_or_public = [visibility | `Public]

let classify_type : Entity_type.t -> [`Public | `Private] = function
  | `Dance | `Person | `Source | `Tune | `User | `Version | `Group -> `Public
  | `Set | `Book -> `Private

(** Handles only the insertion into the ["entities"] table. In particular, this
    function does not handle the ["entity_actors"] table; see
    {!insert_or_update_private}. *)
let insert_to_entities_table db ~is_public type_ =
  let rec make () =
    let id = Id.make () in
    match%lwt Entity_sql.get_type_unsafe db ~id with
    | None ->
      let%lwt _ = Entity_sql.register db ~id ~type_ ~is_public in
      lwt @@ Id.unsafe_coerce id
    | Some _ ->
      make () (* extremely unlikely *)
  in make ()

(** Takes a function [f] that handles inserting/updating to the ["entites"]
    table and handles everything else that has to do with private access. *)
let insert_or_update_private db ~viewers ~owners f =
  let%lwt id = f () in
  ignore <$> Entity_sql.delete_all_actors db ~entity_id: id;%lwt
  Lwt_list.iter_s
    (fun viewer ->
      ignore
      <$> Entity_sql.add_one_actor
          db
          ~entity_id: id
          ~user_id: viewer
          ~role: Viewer
    )
    viewers;%lwt
  Lwt_list.iter_s
    (fun owner ->
      ignore
      <$> Entity_sql.add_one_actor
          db
          ~entity_id: id
          ~user_id: owner
          ~role: Owner
    )
    owners;%lwt
  lwt @@ Id.unsafe_coerce id

let make_public db type_ =
  assert (classify_type type_ = `Public);
  (* Public objects only need the ["entities"] table in which they have no
     visibility field. *)
  insert_to_entities_table db type_ ~is_public: true

let make_private db type_ owner =
  assert (classify_type type_ = `Private);
  insert_or_update_private db ~viewers: [] ~owners: [owner] @@ fun () ->
  insert_to_entities_table db type_ ~is_public: false

let touch db id =
  ignore <$> Entity_sql.touch db ~id: (Id.unsafe_coerce id)

let delete db id =
  let id = Id.unsafe_coerce id in
  ignore <$> Entity_sql.delete_all_actors db ~entity_id: id;%lwt
  ignore <$> Entity_sql.delete db ~id

let get_newest_resources ~actor_id ~limit =
  assert (limit <= 1000);
  Connection.with_ @@ fun db ->
  let%lwt newest =
    Entity_sql.List.get_newest_resources db ~actor_id ~limit: (Int64.of_int limit) (fun ~id ~type_ ->
      let type_ = match type_ with #Resource_type.t as t -> t | _ -> assert false in
      some @@ Resource_id.of_untagged type_ id
    )
  in
  lwt @@ List.filter_map Fun.id newest

let get_permission db ~actor_id id =
  let id = Id.unsafe_coerce id in
  Option.map
    (fun (entity_is_public, actor_role, actor_is_omniscient_administrator) ->
      {Permission.entity_is_public; actor_role; actor_is_omniscient_administrator}
    )
  <$> Entity_sql.get_permission db ~actor_id ~id

let get_actor_roles db id =
  let id = Id.unsafe_coerce id in
  Entity_sql.List.get_actor_roles db ~entity_id: id (fun ~role -> user_sql_to_row ~k: (fun actor -> (actor, role)))

let set_is_public db id is_public =
  let id = Id.unsafe_coerce id in
  ignore <$> Entity_sql.set_is_public db ~id ~is_public

let set_actor_roles db id actor_roles =
  let id = Id.unsafe_coerce id in
  ignore <$> Entity_sql.delete_all_actors db ~entity_id: id;%lwt
  Lwt_list.iter_s
    (fun ({User_row.id = user_id; _}, role) ->
      ignore <$> Entity_sql.add_one_actor db ~entity_id: id ~user_id ~role
    )
    actor_roles

let get_type ~actor_id id =
  Connection.with_ @@ fun db ->
  Entity_sql.Single.get_type db ~actor_id ~id (fun ~type_ -> type_)
