(** {1 Shared code between controllers}

    Because some things are specific but a lot of things in
    controllers are the same, we centralise all of those here. *)

open Nes
open Dancelor_common
open Model_new
open Search_new

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
    | Some person -> lwt person

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
