(** {1 Shared code between controllers}

    Because some things are specific but a lot of things in
    controllers are the same, we centralise all of those here. *)

open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.shared": Logs.LOG)

(** A 404 error that is also returned when trying to read an object to which the
    actor does not have access. This is done to avoid leaking information. *)
let reject_can_get () =
  Madge_server.shortcut_not_found "This entry does not exist, or you do not have access to it."

(* NOTE: Extended version that also handles forms and create/update/delete. This
   should become the only version once we are down integrating the forms. *)

let assert_permission ~access_type ~pp_reason env reason k =
  match reason with
  | None ->
    Log.info (fun m -> m "Refusing %s access to %a." access_type Environment.pp env);
    Madge_server.shortcut_forbidden "You do not have permission to %s this entry" access_type
  | Some reason ->
    Log.debug (fun m -> m "Granting %s access to %a because %a" access_type Environment.pp env pp_reason reason);
    k reason

let assert_can_create _db env =
  assert_permission
    ~access_type: "create"
    ~pp_reason: (fun _fmt _actor -> ())
    env
    (
      match Environment.actor env with
      | Anonymous -> None
      | Signed_in actor -> Some actor
    )

let assert_can_update db env id k =
  let actor_id = Environment.actor_id env in
  let%lwt permission = Database.Entry.get_permission db ~actor_id id in
  assert_permission
    ~access_type: "update"
    ~pp_reason: Permission.pp_edit_reason
    env
    (Option.bind permission Permission.edit_reason)
    (fun _reason -> k ())

let assert_can_delete db env id k =
  let actor_id = Environment.actor_id env in
  let%lwt permission = Database.Entry.get_permission db ~actor_id id in
  assert_permission
    ~access_type: "delete"
    ~pp_reason: Permission.pp_delete_reason
    env
    (Option.bind permission Permission.delete_reason)
    (fun _reason -> k ())

let is_connected env = lwt (Environment.actor env <> Anonymous)

let can_administrate env =
  lwt @@
    match Environment.actor env with
    | Anonymous -> false
    | Signed_in actor -> actor.role = Administrator

let assert_can_administrate env f =
  match Environment.actor env with
  | Anonymous ->
    Log.info (fun m -> m "Refusing admin access to %a." Environment.pp env);
    Madge_server.shortcut_forbidden "You do not have permission to administrate this instance."
  | Signed_in actor ->
    if actor.role = Administrator then
      f actor
    else
      (
        Log.info (fun m -> m "Refusing admin access to %a." Environment.pp env);
        Madge_server.shortcut_forbidden "You do not have permission to administrate this instance."
      )

module type Db_private = sig
  type tag
  type id = tag Id.t
  type row
  type view
  type form
  type query

  val get_row_for : actor_id: User_id.t option -> id list -> (id -> row option) Lwt.t
  val get_view : actor_id: User_id.t option -> id -> view option Lwt.t
  val get_form : actor_id: User_id.t option -> id -> form option Lwt.t
  val search : actor_id: User_id.t option -> query -> (row * float) list Lwt.t

  val create : Database.t -> owner_id: User_id.t -> form -> id Lwt.t
  val update : Database.t -> id -> form -> unit Lwt.t
  val delete : Database.t -> id -> unit Lwt.t
end

module Make_private (Db : Db_private) = struct
  let get_row_for env ids =
    Db.get_row_for ~actor_id: (Environment.actor_id env) ids

  let get_row env id =
    match%lwt (fun f -> f id) <$> get_row_for env [id] with
    | None -> reject_can_get ()
    | Some row -> lwt row

  let get_rows env ids =
    let%lwt row_for = get_row_for env ids in
    lwt @@ List.filter_map row_for ids

  let get_view env id =
    match%lwt Db.get_view ~actor_id: (Environment.actor_id env) id with
    | None -> reject_can_get ()
    | Some view -> lwt view

  let get_form env id =
    match%lwt Db.get_form ~actor_id: (Environment.actor_id env) id with
    | None -> reject_can_get ()
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
    assert_can_create db env @@ fun actor ->
    Db.create db ~owner_id: actor.id form

  let update env id form =
    Database.with_ @@ fun db ->
    assert_can_update db env id @@ fun () ->
    Db.update db id form

  let delete env id =
    Database.with_ @@ fun db ->
    assert_can_delete db env id @@ fun () ->
    Db.delete db id
end

module type Db_public = sig
  type tag
  type id = tag Id.t
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

module Make_public (Db : Db_public) = Make_private(struct
  include Db
  let get_row_for ~actor_id: _ = get_row_for
  let get_view ~actor_id: _ = get_view
  let get_form ~actor_id: _ = get_form
  let search ~actor_id: _ = search
  let create db ~owner_id: _ = create db
end)
