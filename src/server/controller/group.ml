open Nes_unix
open Model_unix

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.group": Logs.LOG)

(* FIXME: Move this controller to use [Shared]. This will require introducing
   proper models for groups and such, which we have been planning to do for a
   long time. *)

let get_row_for _env ids =
  Database.Group.get_row_for ids

let get_row env id =
  match%lwt (fun f -> f id) <$> get_row_for env [id] with
  | None -> Shared.reject_can_get ()
  | Some row -> lwt row

let get_rows env ids =
  let%lwt row_for = get_row_for env ids in
  lwt @@ List.filter_map row_for ids

let get_view _env id =
  match%lwt Database.Group.get_view id with
  | None -> Shared.reject_can_get ()
  | Some view -> lwt view

let get_form env id =
  let%lwt _ = get_view env id in
  Shared.assert_can_edit_group env id @@ fun () ->
  Option.get <$> Database.Group.get_form id

let create env (group : Group_form.t) =
  Shared.assert_can_administrate env @@ fun _admin ->
  Database.with_ @@ fun db ->
  Database.Group.create db group

let update env id (group : Group_form.t) =
  let%lwt _ = get_view env id in
  Shared.assert_can_edit_group env id @@ fun () ->
  Database.with_ @@ fun db ->
  Database.Group.update db id group

let cache : (Environment.cache_key * Group_query.t, (Group_row.t * float) Search_result.t Lwt.t) Cache.t =
  Cache.create ~lifetime: 60 ()

let search' env query =
  Cache.use ~cache ~key: (Environment.cache_key env, query) @@ fun () ->
  let%lwt items = Database.Group.search query in
  lwt {Search_result.total = List.length items; items}

let search env slice query =
  let%lwt {total; items} = search' env query in
  let items = List.map fst @@ Slice.list ~strict: false slice items in
  lwt {Search_result.total; items}

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Group.t -> a = fun env endpoint ->
  match endpoint with
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Create -> create env
  | Update -> update env
  | Search -> search env
