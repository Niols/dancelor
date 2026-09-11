open Nes
open Dancelor_common
open Model_new

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

let get_type db id =
  Entry_sql.get_type db ~id

(** Handles only the insertion into the ["entry"] table. In
    particular, this function does not handle the ["entry_viewers"]
    and ["entry_owners"] tables; see {!insert_or_update_private}. *)
let insert_to_entry_table db ~is_public type_ =
  let rec make () =
    let id = Entry.Id.make () in
    match%lwt get_type db id with
    | None ->
      let%lwt _ = Entry_sql.register db ~id ~type_ ~is_public in
      lwt @@ Entry.Id.unsafe_coerce id
    | Some _ ->
      make () (* extremely unlikely *)
  in make ()

(** Takes a function [f] that handles inserting/updating to the
    ["entry"] table and handles everything else that has to do with
    private access. *)
let insert_or_update_private db access f =
  let%lwt id = f ~is_public: (Entry.Access.Private.is_public access) in
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
    (Entry.Access.Private.viewers access);%lwt
  Lwt_list.iter_s
    (fun owner ->
      ignore
      <$> Entry_sql.add_one_actor
          db
          ~entry_id: id
          ~user_id: owner
          ~role: `Owner
    )
    (Entry.Access.Private.owners access);%lwt
  lwt id

let make_public db type_ =
  assert (classify_type type_ = `Public);
  (* Public objects only need the ["entry"] table in which they have
     no visibility field. *)
  insert_to_entry_table db type_ ~is_public: true

let make_private db type_ access =
  assert (classify_type type_ = `Private);
  insert_or_update_private db access @@ fun ~is_public ->
  insert_to_entry_table db type_ ~is_public

let update_private_access db id access =
  ignore
  <$> insert_or_update_private db access @@ fun ~is_public ->
    ignore <$> Entry_sql.update_is_public db ~id ~is_public;%lwt
    lwt id

let touch db id =
  ignore <$> Entry_sql.touch db ~id

let delete db id =
  ignore <$> Entry_sql.delete_all_actors db ~entry_id: id;%lwt
  ignore <$> Entry_sql.delete db ~id

let get_newest ~user_id ~limit =
  assert (limit <= 1000);
  Connection.with_ @@ fun db ->
  (* FIXME: some gymnastics just because users aren't handled so well yet *)
  let%lwt newest =
    Entry_sql.List.get_newest db ~user_id ~limit: (Int64.of_int limit) (fun ~id ~type_ ->
      some @@
        match type_ with
        | `Book -> Any_id.book @@ Entry.Id.unsafe_coerce id
        | `Dance -> Any_id.dance @@ Entry.Id.unsafe_coerce id
        | `Person -> Any_id.person @@ Entry.Id.unsafe_coerce id
        | `Set -> Any_id.set @@ Entry.Id.unsafe_coerce id
        | `Source -> Any_id.source @@ Entry.Id.unsafe_coerce id
        | `Tune -> Any_id.tune @@ Entry.Id.unsafe_coerce id
        | `User -> Any_id.user @@ Entry.Id.unsafe_coerce id
        | `Version -> Any_id.version @@ Entry.Id.unsafe_coerce id
    )
  in
  lwt @@ List.filter_map Fun.id newest
