open Nes
open Dancelor_common
open Sql_to_row
open Sql_to_view
open Sql_to_form
open Form_to_sql

module Person_sql = Person_sql.Sqlgg(Sqlgg_postgresql)

let get_row_for ids : (Person_id.t -> Person_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  Utils.fold_to_get_single (Person_sql.Fold.get_rows db ~ids) (fun k ~id -> person_sql_to_row ~id ~k: (k id))

let get_view id : Person_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  Person_sql.Single.get_view db ~id (person_sql_to_view ~k: Fun.id)

let get_form id : Person_form.t option Lwt.t =
  Connection.with_ @@ fun db ->
  Person_sql.Single.get_form db ~id (person_sql_to_form ~k: Fun.id)

let search query : (Person_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = ()} = query in
  Connection.with_ @@ fun db ->
  Person_sql.List.search
    db
    ~terms
    (fun ~score -> person_sql_to_row ~k: (Pair.snoc score))

let create db person =
  let%lwt id = Entry.make_public db `Person in
  let%lwt _ = person_form_to_sql (Person_sql.create db) id person in
  lwt id

let update db id person =
  Entry.touch db id;%lwt
  ignore <$> person_form_to_sql (fun ~id -> Person_sql.update db ~id) id person

let delete db id =
  ignore <$> Person_sql.delete db ~id;%lwt
  Entry.delete db id
