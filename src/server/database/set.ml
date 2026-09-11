open Nes
open Dancelor_common
open Model_new
open Search_new
open Sql_to_name
open Sql_to_row
open Sql_to_view

module Entry_sql = Entry_sql.Sqlgg(Sqlgg_postgresql)
module Set_sql = Set_sql.Sqlgg(Sqlgg_postgresql)

let get_tune_composers_for db set_ids =
  Utils.fold_to_get_list (Set_sql.Fold.get_tune_composers_for db ~set_ids) (fun k ~tune_id -> person_sql_to_name ~k: (k tune_id))

let get_version_sources_for db set_ids =
  Utils.fold_to_get_list (Set_sql.Fold.get_version_sources_for db ~set_ids) (fun k ~version_id -> source_sql_to_short_name ~k: (k version_id))

let get_version_arrangers_for db set_ids =
  Utils.fold_to_get_list (Set_sql.Fold.get_version_arrangers_for db ~set_ids) (fun k ~version_id -> person_sql_to_name ~k: (k version_id))

let get_tunes_for db set_ids =
  Utils.fold_to_get_list (Set_sql.Fold.get_tunes_for db ~set_ids) (fun k ~set_id ~id -> version_sql_to_name ~id ~k: (k set_id))

let get_conceptors_for db set_ids =
  Utils.fold_to_get_list (Set_sql.Fold.get_conceptors_for db ~set_ids) (fun k ~set_id -> person_sql_to_name ~k: (k set_id))

let get_content_for db set_ids =
  let%lwt tune_composers_for = get_tune_composers_for db set_ids in
  let%lwt version_sources_for = get_version_sources_for db set_ids in
  let%lwt version_arrangers_for = get_version_arrangers_for db set_ids in
  Utils.fold_to_get_list
    (Set_sql.Fold.get_content_for db ~set_ids)
    (fun
        k
        ~set_id
        ~version_id
        ~tune_id
        ~version_disambiguation
        ~version_monolithic_bars
        ~version_monolithic_or_default_structure
        ~tune_name
        ~tune_kind
        ~version_parameter_transposition_semitones
        ~version_parameter_first_bar
        ~version_parameter_clef
        ~version_parameter_structure
        ~version_parameter_trivia
        ~version_parameter_display_name
        ~version_parameter_display_composer
      ->
      let version =
        version_sql_to_row
          ~id: version_id
          ~tune_id
          ~disambiguation: version_disambiguation
          ~monolithic_bars: version_monolithic_bars
          ~monolithic_or_default_structure: version_monolithic_or_default_structure
          ~tune_name
          ~tune_kind
          ~tune_composers: (tune_composers_for tune_id)
          ~sources: (version_sources_for version_id)
          ~arrangers: (version_arrangers_for version_id)
          ~k: Fun.id
      in
      let params =
        Model_builder.Core.Version_parameters.make
          ?transposition: (Option.map (Transposition.from_semitones % Int64.to_int) version_parameter_transposition_semitones)
          ?first_bar: (Option.map Int64.to_int version_parameter_first_bar)
          ?clef: (Option.map Music.Clef.of_string version_parameter_clef)
          ?structure: (Option.map (Option.get % Model_builder.Core.Version_parameters.maybe_structure_of_string % NEString.of_string_exn) version_parameter_structure)
          ?trivia: version_parameter_trivia
          ?display_name: (Option.map NEString.of_string_exn version_parameter_display_name)
          ?display_composer: (Option.map NEString.of_string_exn version_parameter_display_composer)
          ()
      in
      k set_id (version, params)
    )

let get_row_for ~user_id ids : (Set_id.t -> Set_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt tunes_for = get_tunes_for db (`One_of ids) in
  let%lwt conceptors_for = get_conceptors_for db (`One_of ids) in
  Utils.fold_to_get_single
    (Set_sql.Fold.get_rows db ~ids ~user_id)
    (fun k ~id ->
      set_sql_to_row
        ~id
        ~tunes: (tunes_for id)
        ~conceptors: (conceptors_for id)
        ~k: (k id)
    )

let get_view ~user_id id : Set_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt conceptors = (fun f -> f id) <$> get_conceptors_for db (`One_of [id]) in
  let%lwt content = (fun f -> f id) <$> get_content_for db (`One_of [id]) in
  Set_sql.Single.get_view
    db
    ~user_id
    ~id
    (set_sql_to_view ~conceptors ~content ~k: Fun.id)

let search ~user_id query : (Set_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = {Set_query.conceptor; contains_version; contains_tune}} = query in
  Connection.with_ @@ fun db ->
  let%lwt tunes_for = get_tunes_for db `All in
  let%lwt conceptors_for = get_conceptors_for db `All in
  Set_sql.List.search
    db
    ~user_id
    ~terms
    ~conceptor: (Utils.option_to_sql conceptor)
    ~contains_version: (Utils.option_to_sql contains_version)
    ~contains_tune: (Utils.option_to_sql contains_tune)
    (fun ~score ~id ->
      set_sql_to_row
        ~id
        ~tunes: (tunes_for id)
        ~conceptors: (conceptors_for id)
        ~k: (Pair.snoc score)
    )

(* Legacy *)

type t = Model_builder.Core.Set.t
type entry = Model_builder.Core.Set.entry

let sql_to_set
    ~id
    ~name
    ~kind
    ~order
    ~remark
    ~created_at
    ~modified_at
    ~is_public
    ~conceptors
    ~content
    ~owners
    ~viewers
  =
  Entry.make
    ~id: id
    ~meta: (Entry.Meta.make ~created_at ~modified_at ())
    ~access: (Entry.Access.Private.make ~owners ~viewers ~is_public ())
    (
      Model_builder.Core.Set.make
        ~name: (NEString.of_string_exn name)
        ~conceptors
        ~kind: (Kind_dance.of_string kind)
        ~contents: content
        ~order: (Model_builder.Core.Set_order.of_string order)
        ~remark: (Option.map NEString.of_string_exn remark)
        ()
    )

let set_to_sql ~create_or_update db id set =
  ignore
  <$> create_or_update
      db
      ~id
      ~name: (NEString.to_string @@ Model_builder.Core.Set.name set)
      ~kind: (Kind_dance.to_string @@ Model_builder.Core.Set.kind set)
      ~order: (Model_builder.Core.Set_order.to_string @@ Model_builder.Core.Set.order set)
      ~remark: (Option.map NEString.to_string @@ Model_builder.Core.Set.remark set);%lwt
  ignore <$> Set_sql.delete_all_conceptors db ~set_id: id;%lwt
  Lwt_list.iter_s
    (fun conceptor ->
      ignore
      <$> Set_sql.add_one_conceptor
          db
          ~set_id: id
          ~conceptor_id: conceptor
    )
    (Model_builder.Core.Set.conceptors set);%lwt
  ignore <$> Set_sql.delete_all_content db ~set_id: id;%lwt
  Lwt_list.iteri_s
    (fun index (version, params) ->
      ignore
      <$> Set_sql.add_one_content_item
          db
          ~set_id: id
          ~index: (Int64.of_int index)
          ~version_id: version
          ~version_parameter_transposition_semitones: (Option.map (Int64.of_int % Transposition.to_semitones) @@ Model_builder.Core.Version_parameters.transposition params)
          ~version_parameter_first_bar: (Option.map Int64.of_int @@ Model_builder.Core.Version_parameters.first_bar params)
          ~version_parameter_clef: (Option.map Music.Clef.to_string @@ Model_builder.Core.Version_parameters.clef params)
          ~version_parameter_structure: (Option.map (NEString.to_string % Model_builder.Core.Version_parameters.maybe_structure_to_string) @@ Model_builder.Core.Version_parameters.structure params)
          ~version_parameter_trivia: (Model_builder.Core.Version_parameters.trivia params)
          ~version_parameter_display_name: (Option.map NEString.to_string @@ Model_builder.Core.Version_parameters.display_name params)
          ~version_parameter_display_composer: (Option.map NEString.to_string @@ Model_builder.Core.Version_parameters.display_composer params)
    )
    (Model_builder.Core.Set.contents set)

let get id : Model_builder.Core.Set.entry option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt conceptors = Set_sql.List.get_conceptors db ~set_id: id (fun ~conceptor_id -> conceptor_id) in
  let%lwt (owners, viewers) =
    List.partition_map (function (`Owner, user_id) -> Left user_id | (`Viewer, user_id) -> Right user_id)
    <$> Entry_sql.List.get_actors db ~entry_id: id (fun ~user_id ~role -> (role, user_id))
  in
  let%lwt content =
    Set_sql.List.get_content db ~set_id: id (fun
        ~version_id
        ~version_parameter_transposition_semitones
        ~version_parameter_first_bar
        ~version_parameter_clef
        ~version_parameter_structure
        ~version_parameter_trivia
        ~version_parameter_display_name
        ~version_parameter_display_composer
      ->
      (
        version_id,
        Model_builder.Core.Version_parameters.make
          ?transposition: (Option.map (Transposition.from_semitones % Int64.to_int) version_parameter_transposition_semitones)
          ?first_bar: (Option.map Int64.to_int version_parameter_first_bar)
          ?clef: (Option.map Music.Clef.of_string version_parameter_clef)
          ?structure: (Option.map (Option.get % Model_builder.Core.Version_parameters.maybe_structure_of_string % NEString.of_string_exn) version_parameter_structure)
          ?trivia: version_parameter_trivia
          ?display_name: (Option.map NEString.of_string_exn version_parameter_display_name)
          ?display_composer: (Option.map NEString.of_string_exn version_parameter_display_composer)
          ()
      )
    )
  in
  Set_sql.Single.get db ~id (sql_to_set ~id ~conceptors ~viewers ~owners ~content)

let create set access =
  Connection.with_ @@ fun db ->
  let%lwt id = Entry_new.make_private db `Set access in
  set_to_sql ~create_or_update: Set_sql.create db id set;%lwt
  lwt id

let update id set access =
  Connection.with_ @@ fun db ->
  Entry_new.touch db id;%lwt
  Entry_new.update_private_access db id access;%lwt
  set_to_sql ~create_or_update: (fun db ~id -> Set_sql.update db ~id) db id set

let delete id =
  Connection.with_ @@ fun db ->
  ignore <$> Set_sql.delete_all_conceptors db ~set_id: id;%lwt
  ignore <$> Set_sql.delete_all_content db ~set_id: id;%lwt
  ignore <$> Set_sql.delete db ~id;%lwt
  Entry_new.delete db id
