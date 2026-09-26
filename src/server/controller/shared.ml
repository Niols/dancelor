(** {1 Shared code between controllers}

    Because some things are specific but a lot of things in
    controllers are the same, we centralise all of those here. *)

open Nes
open Dancelor_common
open Model_new
open Search_new

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.shared": Logs.LOG)

module type Db_private = sig
  type id
  type row
  type view
  type query

  val get_row_for : actor_id: User_id.t option -> id list -> (id -> row option) Lwt.t
  val get_view : actor_id: User_id.t option -> id -> view option Lwt.t
  val search : actor_id: User_id.t option -> query -> (row * float) list Lwt.t
end

module Make_private (Db : Db_private) = struct
  let get_row_for env ids =
    Db.get_row_for ~actor_id: (Environment.actor_id env) ids

  let get_row env id =
    match%lwt (fun f -> f id) <$> get_row_for env [id] with
    | None -> Permission.reject_can_get ()
    | Some row -> lwt row

  let get_rows env ids =
    let%lwt row_for = get_row_for env ids in
    lwt @@ List.filter_map row_for ids

  let get_view env id =
    match%lwt Db.get_view ~actor_id: (Environment.actor_id env) id with
    | None -> Permission.reject_can_get ()
    | Some view -> lwt view

  let cache : (Environment.cache_key * Db.query, (Db.row * float) Search_result.t Lwt.t) Cache.t =
    Cache.create ~lifetime: 60 ()

  let search' env query =
    Cache.use ~cache ~key: (Environment.cache_key env, query) @@ fun () ->
    let%lwt items = Db.search ~actor_id: (Environment.actor_id env) query in
    lwt {Search_result.total = List.length items; items}

  let search env slice query =
    let%lwt {total; items} = search' env query in
    let items = List.map fst @@ Slice.list ~strict: false slice items in
    lwt {Search_result.total; items}
end

module type Db_public = sig
  type id
  type row
  type view
  type query

  val get_row_for : id list -> (id -> row option) Lwt.t
  val get_view : id -> view option Lwt.t
  val search : query -> (row * float) list Lwt.t
end

module Make_public (Db : Db_public) = Make_private(struct
  include Db
  let get_row_for ~actor_id: _ = get_row_for
  let get_view ~actor_id: _ = get_view
  let search ~actor_id: _ = search
end)

(* NOTE: Extended version that also handles forms and create/update/delete. This
   should become the only version once we are down integrating the forms. *)

let assert_permission ~access_type ~pp_reason env reason =
  match reason with
  | None ->
    Log.info (fun m -> m "Refusing %s access to %a." access_type Environment.pp env);
    Madge_server.shortcut_forbidden "You do not have permission to %s this entry" access_type
  | Some reason ->
    Log.debug (fun m -> m "Granting %s access to %a because %a" access_type Environment.pp env pp_reason reason);
    lwt_unit

let assert_can_create _db env =
  assert_permission
    ~access_type: "create"
    ~pp_reason: (fun _fmt () -> ())
    env
    (
      match Environment.actor env with
      | Anonymous -> None
      | Signed_in _actor -> Some ()
    )

let assert_can_update db env id =
  let actor_id = Environment.actor_id env in
  let%lwt permission = Database.Entry.get_permission db ~actor_id id in
  assert_permission
    ~access_type: "update"
    ~pp_reason: Permission_new.pp_edit_reason
    env
    (Option.bind permission Permission_new.edit_reason)

let assert_can_delete db env id =
  let actor_id = Environment.actor_id env in
  let%lwt permission = Database.Entry.get_permission db ~actor_id id in
  assert_permission
    ~access_type: "delete"
    ~pp_reason: Permission_new.pp_delete_reason
    env
    (Option.bind permission Permission_new.delete_reason)

module type Db_private_full = sig
  type entry
  type id = entry Entry.Id.t
  type row
  type view
  type form
  type query

  val get_row_for : actor_id: User_id.t option -> id list -> (id -> row option) Lwt.t
  val get_view : actor_id: User_id.t option -> id -> view option Lwt.t
  val get_form : actor_id: User_id.t option -> id -> form option Lwt.t
  val search : actor_id: User_id.t option -> query -> (row * float) list Lwt.t

  val create : Database.t -> form -> id Lwt.t
  val update : Database.t -> id -> form -> unit Lwt.t
  val delete : Database.t -> id -> unit Lwt.t
end

module Make_private_full (Db : Db_private_full) = struct
  let get_row_for env ids =
    Db.get_row_for ~actor_id: (Environment.actor_id env) ids

  let get_row env id =
    match%lwt (fun f -> f id) <$> get_row_for env [id] with
    | None -> Permission.reject_can_get ()
    | Some row -> lwt row

  let get_rows env ids =
    let%lwt row_for = get_row_for env ids in
    lwt @@ List.filter_map row_for ids

  let get_view env id =
    match%lwt Db.get_view ~actor_id: (Environment.actor_id env) id with
    | None -> Permission.reject_can_get ()
    | Some view -> lwt view

  let get_form env id =
    match%lwt Db.get_form ~actor_id: (Environment.actor_id env) id with
    | None -> Permission.reject_can_get ()
    | Some form -> lwt form

  let cache : (Environment.cache_key * Db.query, (Db.row * float) Search_result.t Lwt.t) Cache.t =
    Cache.create ~lifetime: 60 ()

  let search' env query =
    Cache.use ~cache ~key: (Environment.cache_key env, query) @@ fun () ->
    let%lwt items = Db.search ~actor_id: (Environment.actor_id env) query in
    lwt {Search_result.total = List.length items; items}

  let search env slice query =
    let%lwt {total; items} = search' env query in
    let items = List.map fst @@ Slice.list ~strict: false slice items in
    lwt {Search_result.total; items}

  let create env form =
    Database.with_ @@ fun db ->
    assert_can_create db env;%lwt
    Db.create db form

  let update env id form =
    Database.with_ @@ fun db ->
    assert_can_update db env id;%lwt
    Db.update db id form

  let delete env id =
    Database.with_ @@ fun db ->
    assert_can_delete db env id;%lwt
    Db.delete db id
end

module type Db_public_full = sig
  type entry
  type id = entry Entry.Id.t
  type row
  type view
  type form
  type query

  val get_row_for : id list -> (id -> row option) Lwt.t
  val get_view : id -> view option Lwt.t
  val get_form : id -> form option Lwt.t
  val search : query -> (row * float) list Lwt.t

  val create : Database.t -> form -> id Lwt.t
  val update : Database.t -> id -> form -> unit Lwt.t
  val delete : Database.t -> id -> unit Lwt.t
end

module Make_public_full (Db : Db_public_full) = Make_private_full(struct
  include Db
  let get_row_for ~actor_id: _ = get_row_for
  let get_view ~actor_id: _ = get_view
  let get_form ~actor_id: _ = get_form
  let search ~actor_id: _ = search
end)
