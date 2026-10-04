open Nes
open Dancelor_common
open Sql_to_name
open Sql_to_row
open Sql_to_view
open Sql_to_form
open Form_to_sql

module Dance_sql = Dance_sql.Sqlgg(Sqlgg_postgresql)

let get_extra_names_for db dance_ids =
  Utils.fold_to_get_list (Dance_sql.Fold.get_extra_names_for db ~dance_ids) (fun k ~dance_id ~extra_name -> k dance_id extra_name)

let get_devisers_for db dance_ids =
  Utils.fold_to_get_list (Dance_sql.Fold.get_devisers_for db ~dance_ids) (fun k ~dance_id -> person_sql_to_name ~k: (k dance_id))

let get_tunes_for db dance_ids =
  let%lwt composers_for = Utils.fold_to_get_list (Dance_sql.Fold.get_composers_for_tunes_for db ~dance_ids) (fun k ~tune_id -> person_sql_to_name ~k: (k tune_id)) in
  Utils.fold_to_get_list (Dance_sql.Fold.get_tunes_for db ~dance_ids) (fun k ~dance_id ~id -> tune_sql_to_row ~id ~composers: (composers_for id) ~k: (k dance_id))

let get_row_for ids : (Dance_id.t -> Dance_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt devisers_for = get_devisers_for db (`One_of ids) in
  Utils.fold_to_get_single (Dance_sql.Fold.get_rows db ~ids: (`One_of ids)) (fun k ~id -> dance_sql_to_row ~id ~devisers: (devisers_for id) ~k: (k id))

let get_view id : Dance_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt extra_names = (fun f -> f id) <$> get_extra_names_for db (`One_of [id]) in
  let%lwt devisers = (fun f -> f id) <$> get_devisers_for db (`One_of [id]) in
  let%lwt tunes = (fun f -> f id) <$> get_tunes_for db (`One_of [id]) in
  Dance_sql.Single.get_view db ~id (dance_sql_to_view ~extra_names ~devisers ~tunes ~k: Fun.id)

let get_form id : Dance_form.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt extra_names = (fun f -> f id) <$> get_extra_names_for db (`One_of [id]) in
  let%lwt devisers = (fun f -> f id) <$> get_devisers_for db (`One_of [id]) in
  Dance_sql.Single.get_form db ~id (dance_sql_to_form ~extra_names ~devisers ~k: Fun.id)

let search query : (Dance_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = {Dance_query.deviser}} = query in
  Connection.with_ @@ fun db ->
  let%lwt devisers_for = get_devisers_for db `All in
  Dance_sql.List.search
    db
    ~terms
    ~deviser: (Utils.option_to_sql deviser)
    (fun ~score ~id -> dance_sql_to_row ~id ~devisers: (devisers_for id) ~k: (Pair.snoc score))

let update_other_tables db ~dance_id ~extra_names ~devisers =
  ignore <$> Dance_sql.delete_all_extra_names db ~dance_id;%lwt
  Lwt_list.iter_s
    (fun extra_name ->
      ignore <$> Dance_sql.add_one_extra_name db ~dance_id ~extra_name: (NEString.to_string extra_name)
    )
    extra_names;%lwt
  ignore <$> Dance_sql.delete_all_devisers db ~dance_id;%lwt
  Lwt_list.iteri_s
    (fun index deviser ->
      ignore <$> Dance_sql.add_one_deviser db ~dance_id ~index: (Int64.of_int index) ~deviser_id: (Person_row.id deviser)
    )
    devisers

let create db dance =
  let%lwt id = Entry_new.make_public db `Dance in
  ignore <$> dance_form_to_sql (Dance_sql.create db) id dance;%lwt
  update_other_tables db ~dance_id: id ~extra_names: (NEList.tl dance.names) ~devisers: dance.devisers;%lwt
  lwt id

let update db id dance =
  Entry_new.touch db id;%lwt
  ignore <$> dance_form_to_sql (fun ~id -> Dance_sql.update db ~id) id dance;%lwt
  update_other_tables db ~dance_id: id ~extra_names: (NEList.tl dance.names) ~devisers: dance.devisers

let delete db id =
  ignore <$> Dance_sql.delete_all_extra_names db ~dance_id: id;%lwt
  ignore <$> Dance_sql.delete_all_devisers db ~dance_id: id;%lwt
  ignore <$> Dance_sql.delete db ~id;%lwt
  Entry_new.delete db id
