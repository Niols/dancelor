open Nes
open Dancelor_common
open Sql_to_name
open Sql_to_row
open Sql_to_view
open Sql_to_form
open Form_to_sql

module Tune_sql = Tune_sql.Sqlgg(Sqlgg_postgresql)

let get_extra_names_for db tune_ids =
  Utils.fold_to_get_list (Tune_sql.Fold.get_extra_names_for db ~tune_ids) (fun k ~tune_id ~extra_name -> k tune_id extra_name)

let get_dances_for db tune_ids =
  let%lwt devisers_for = Utils.fold_to_get_list (Tune_sql.Fold.get_devisers_for_dances_of db ~tune_ids) (fun k ~dance_id -> person_sql_to_name ~k: (k dance_id)) in
  Utils.fold_to_get_list (Tune_sql.Fold.get_dances_for db ~tune_ids) (fun k ~tune_id ~id -> dance_sql_to_row ~id ~devisers: (devisers_for id) ~k: (k tune_id))

let get_versions_for db tune_ids =
  let%lwt sources_for = Utils.fold_to_get_list (Tune_sql.Fold.get_sources_for_versions_of db ~tune_ids) (fun k ~version_id -> source_sql_to_short_name ~k: (k version_id)) in
  let%lwt arrangers_for = Utils.fold_to_get_list (Tune_sql.Fold.get_arrangers_for_versions_of db ~tune_ids) (fun k ~version_id -> person_sql_to_name ~k: (k version_id)) in
  Utils.fold_to_get_list (Tune_sql.Fold.get_versions_for db ~tune_ids) (fun k ~id ~tune_id -> tune_sql_to_version_row_without_tune ~id ~arrangers: (arrangers_for id) ~sources: (sources_for id) ~k: (k tune_id))

let get_composers_for db tune_ids =
  Utils.fold_to_get_list (Tune_sql.Fold.get_composers_for db ~tune_ids) (fun k ~tune_id -> person_sql_to_name ~k: (k tune_id))

let get_composers_for_tunes_of_dances db dance_ids =
  Utils.fold_to_get_list (Tune_sql.Fold.get_composers_for_tunes_of_dances db ~dance_ids) (fun k ~tune_id -> person_sql_to_name ~k: (k tune_id))

let get_composers_with_details_for db tune_ids =
  Utils.fold_to_get_list (Tune_sql.Fold.get_composers_with_details_for db ~tune_ids) (fun k ~tune_id -> person_sql_to_name_with_details ~k: (k tune_id))

let get_composers_with_details_for' db tune_ids =
  Utils.fold_to_get_list (Tune_sql.Fold.get_composers_with_details_for db ~tune_ids) (fun k ~tune_id -> person_sql_to_tune_composer ~k: (k tune_id))

let get_row_for ids : (Tune_id.t -> Tune_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt composers_for = get_composers_for db (`One_of ids) in
  Utils.fold_to_get_single (Tune_sql.Fold.get_rows db ~ids) (fun k ~id -> tune_sql_to_row ~id ~composers: (composers_for id) ~k: (k id))

let get_rows_for_dance dance_id : Tune_row.t list Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt composers_for = get_composers_for_tunes_of_dances db (`One_of [dance_id]) in
  Tune_sql.List.get_rows_for_dance
    db
    ~dance_id
    (fun ~id -> tune_sql_to_row ~id ~composers: (composers_for id) ~k: Fun.id)

let get_view id : Tune_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt extra_names = (fun f -> f id) <$> get_extra_names_for db (`One_of [id]) in
  let%lwt dances = (fun f -> f id) <$> get_dances_for db (`One_of [id]) in
  let%lwt versions = (fun f -> f id) <$> get_versions_for db (`One_of [id]) in
  let%lwt composers = (fun f -> f id) <$> get_composers_with_details_for db (`One_of [id]) in
  Tune_sql.Single.get_view db ~id (tune_sql_to_view ~extra_names ~dances ~composers ~versions ~k: Fun.id)

let get_form id : Tune_form.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt extra_names = (fun f -> f id) <$> get_extra_names_for db (`One_of [id]) in
  let%lwt dances = (fun f -> f id) <$> get_dances_for db (`One_of [id]) in
  let%lwt composers = (fun f -> f id) <$> get_composers_with_details_for' db (`One_of [id]) in
  Tune_sql.Single.get_form db ~id (tune_sql_to_form ~extra_names ~dances ~composers ~k: Fun.id)

let search query : (Tune_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = {Tune_query.kind; composer}} = query in
  Connection.with_ @@ fun db ->
  let%lwt composers_for = get_composers_for db `All in
  Tune_sql.List.search
    db
    ~terms
    ~kind: (Option.map (List.map Sql_types.kind_base_of_common) kind)
    ~composer: (Utils.option_to_sql composer)
    (fun ~score ~id -> tune_sql_to_row ~id ~composers: (composers_for id) ~k: (Pair.snoc score))

let update_other_tables db ~tune_id ~extra_names ~composers ~dances =
  ignore <$> Tune_sql.delete_all_extra_names db ~tune_id;%lwt
  Lwt_list.iter_s
    (fun extra_name ->
      ignore <$> Tune_sql.add_one_extra_name db ~tune_id ~extra_name: (NEString.to_string extra_name)
    )
    extra_names;%lwt
  ignore <$> Tune_sql.delete_all_composers db ~tune_id;%lwt
  Lwt_list.iteri_s
    (fun index {Tune_form.composer; details} ->
      ignore
      <$> Tune_sql.add_one_composer
          db
          ~tune_id
          ~index: (Int64.of_int index)
          ~composer_id: composer.id
          ~details: (Option.map NEString.to_string details)
    )
    composers;%lwt
  ignore <$> Tune_sql.delete_all_dances db ~tune_id;%lwt
  Lwt_list.iter_s
    (fun {Dance_row.id; _} ->
      ignore <$> Tune_sql.add_one_dance db ~tune_id ~dance_id: id
    )
    dances

let create db tune =
  let%lwt id = Entry.make_public db `Tune in
  ignore <$> tune_form_to_sql (Tune_sql.create db) id tune;%lwt
  update_other_tables db ~tune_id: id ~extra_names: (NEList.tl tune.names) ~composers: tune.composers ~dances: tune.dances;%lwt
  lwt id

let update db id tune =
  Entry.touch db id;%lwt
  ignore <$> tune_form_to_sql (fun ~id -> Tune_sql.update db ~id) id tune;%lwt
  update_other_tables db ~tune_id: id ~extra_names: (NEList.tl tune.names) ~composers: tune.composers ~dances: tune.dances

let delete db id =
  ignore <$> Tune_sql.delete_all_extra_names db ~tune_id: id;%lwt
  ignore <$> Tune_sql.delete_all_composers db ~tune_id: id;%lwt
  ignore <$> Tune_sql.delete_all_dances db ~tune_id: id;%lwt
  ignore <$> Tune_sql.delete db ~id;%lwt
  Entry.delete db id
