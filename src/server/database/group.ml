open Nes_unix
open Dancelor_common
open Sql_to_row
open Sql_to_view
open Sql_to_form
open Form_to_sql

module Group_sql = Group_sql.Sqlgg(Sqlgg_postgresql)

let get_row_for ids : (Group_id.t -> Group_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  Utils.fold_to_get_single (Group_sql.Fold.get_rows db ~ids) (fun k ~id -> group_sql_to_row ~id ~k: (k id))

let get_row id =
  (fun f -> f id) <$> get_row_for [id]

let get_members_for db group_ids =
  Utils.fold_to_get_list (Group_sql.Fold.get_members_for db ~group_ids) (fun k ~group_id -> user_sql_to_row ~k: (k group_id))

let get_view id : Group_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt members = (fun f -> f id) <$> get_members_for db (`One_of [id]) in
  Group_sql.Single.get_view db ~id (group_sql_to_view ~id ~members ~k: Fun.id)

let get_form id : Group_form.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt members = (fun f -> f id) <$> get_members_for db (`One_of [id]) in
  Group_sql.Single.get_form db ~id (group_sql_to_form ~id ~members ~k: Fun.id)

let search query : (Group_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = ()} = query in
  Connection.with_ @@ fun db ->
  Group_sql.List.search
    db
    ~terms
    (fun ~score -> group_sql_to_row ~k: (Pair.snoc score))

let update_other_tables db ~group_id ~members =
  ignore <$> Group_sql.delete_all_members db ~group_id;%lwt
  Lwt_list.iter_s
    (fun member ->
      ignore <$> Group_sql.add_one_member db ~group_id ~member_id: (User_row.id member)
    )
    members

let create db group =
  let%lwt id = Entity.make_public db `Group in
  ignore <$> group_form_to_sql (Group_sql.create db) id group;%lwt
  update_other_tables db ~group_id: id ~members: group.members;%lwt
  lwt id

let update db id group =
  Entity.touch db id;%lwt
  ignore <$> group_form_to_sql (fun ~id -> Group_sql.update db ~id) id group;%lwt
  update_other_tables db ~group_id: id ~members: group.members
