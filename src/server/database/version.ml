open Nes
open Dancelor_common
open Sql_to_name
open Sql_to_row
open Sql_to_view
open Sql_to_form
open Form_to_sql

module Version_sql = Version_sql.Sqlgg(Sqlgg_postgresql)

let get_tune_extra_names_for db version_ids =
  Utils.fold_to_get_list (Version_sql.Fold.get_tune_extra_names_for db ~version_ids) (fun k ~tune_id ~extra_name -> k tune_id extra_name)

let get_tune_dances_for db version_ids =
  let%lwt devisers_for = Utils.fold_to_get_list (Version_sql.Fold.get_devisers_for_dances_of db ~version_ids) (fun k ~dance_id -> person_sql_to_name ~k: (k dance_id)) in
  Utils.fold_to_get_list (Version_sql.Fold.get_dances_for db ~version_ids) (fun k ~tune_id ~id -> dance_sql_to_row ~id ~devisers: (devisers_for id) ~k: (k tune_id))

let get_tune_composers_for db version_ids =
  Utils.fold_to_get_list (Version_sql.Fold.get_tune_composers_for db ~version_ids) (fun k ~tune_id -> person_sql_to_name ~k: (k tune_id))

let get_tune_composers_with_details_for db version_ids =
  Utils.fold_to_get_list (Version_sql.Fold.get_tune_composers_with_details_for db ~version_ids) (fun k ~tune_id -> person_sql_to_name_with_details ~k: (k tune_id))

let get_sources_for db version_ids =
  Utils.fold_to_get_list (Version_sql.Fold.get_sources_for db ~version_ids) (fun k ~version_id -> source_sql_to_short_name ~k: (k version_id))

let get_version_sources_for db version_ids =
  Utils.fold_to_get_list (Version_sql.Fold.get_version_sources_for db ~version_ids) (fun k ~version_id -> version_sql_to_source ~k: (k version_id))

let get_version_form_sources_for db version_ids =
  let%lwt editors_for = Utils.fold_to_get_list (Version_sql.Fold.get_editors_for_sources_of db ~version_ids) (fun k ~source_id -> person_sql_to_name ~k: (k source_id)) in
  Utils.fold_to_get_list (Version_sql.Fold.get_version_form_sources_for db ~version_ids) (fun k ~version_id ~id -> version_sql_to_form_source ~id ~editors: (editors_for id) ~k: (k version_id))

let get_arrangers_for db version_ids =
  Utils.fold_to_get_list (Version_sql.Fold.get_arrangers_for db ~version_ids) (fun k ~version_id -> person_sql_to_name ~k: (k version_id))

let get_other_versions_for db version_ids =
  let%lwt sources_for = Utils.fold_to_get_list (Version_sql.Fold.get_sources_for_other_versions_of db ~version_ids) (fun k ~version_id -> source_sql_to_short_name ~k: (k version_id)) in
  let%lwt arrangers_for = Utils.fold_to_get_list (Version_sql.Fold.get_arrangers_for_other_versions_of db ~version_ids) (fun k ~version_id -> person_sql_to_name ~k: (k version_id)) in
  Utils.fold_to_get_list (Version_sql.Fold.get_other_versions_for db ~version_ids) (fun k ~id ~tune_id -> tune_sql_to_version_row_without_tune ~id ~arrangers: (arrangers_for id) ~sources: (sources_for id) ~k: (k tune_id))

let get_destructured_parts_for =
  let check_destructured_parts =
    (* NOTE: A bit weird: on the OCaml side, part names are implicit and just come
       from the order in the list, while in SQL we store the part name/number. SQL
       sorts for us, but now we need to check that they correspond. *)
    List.mapi (fun i (part, voices) ->
      if Model_builder.Core.Version.Part_name.to_int part <> i then assert false
      else voices
    )
  in
  fun db version_ids ->
    let%lwt get_list =
      Utils.fold_to_get_list
        (Version_sql.Fold.get_destructured_parts_for db ~version_ids)
        (fun k ~version_id ~part ~melody ~chords ->
          k version_id (
            Option.get (Model_builder.Core.Version.Part_name.of_string part),
            {Model_builder.Core.Version.Voices.melody; chords}
          )
        )
    in
    lwt (check_destructured_parts % get_list)

let get_destructured_transitions_for db version_ids =
  Utils.fold_to_get_list
    (Version_sql.Fold.get_destructured_transitions_for db ~version_ids)
    (fun k ~version_id ~from_parts ~to_parts ~melody ~chords ->
      k version_id (
        Option.get (Model_builder.Core.Version.Part_name.opens_of_string from_parts),
        Option.get (Model_builder.Core.Version.Part_name.opens_of_string to_parts),
        {Model_builder.Core.Version.Voices.melody; chords}
      )
    )

let get_row_for ids : (Version_id.t -> Version_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt tune_composers_for = get_tune_composers_for db (`One_of ids) in
  let%lwt sources_for = get_sources_for db (`One_of ids) in
  let%lwt arrangers_for = get_arrangers_for db (`One_of ids) in
  Utils.fold_to_get_single
    (Version_sql.Fold.get_rows db ~ids)
    (fun k ~id ~tune_id ->
      version_sql_to_row
        ~id
        ~tune_id
        ~tune_composers: (tune_composers_for tune_id)
        ~sources: (sources_for id)
        ~arrangers: (arrangers_for id)
        ~k: (k id)
    )

let get_view id : Version_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt tune_extra_names_for = get_tune_extra_names_for db (`One_of [id]) in
  let%lwt tune_dances_for = get_tune_dances_for db (`One_of [id]) in
  let%lwt other_versions_for = get_other_versions_for db (`One_of [id]) in
  let%lwt tune_composers_for = get_tune_composers_with_details_for db (`One_of [id]) in
  let%lwt arrangers = (fun f -> f id) <$> get_arrangers_for db (`One_of [id]) in
  let%lwt sources = (fun f -> f id) <$> get_version_sources_for db (`One_of [id]) in
  Version_sql.Single.get_view db ~id (fun ~id ~tune_id ->
    version_sql_to_view
      ~id
      ~tune_id
      ~arrangers
      ~sources
      ~tune_extra_names: (tune_extra_names_for tune_id)
      ~tune_dances: (tune_dances_for tune_id)
      ~tune_composers: (tune_composers_for tune_id)
      ~tune_versions: (other_versions_for tune_id)
      ~k: Fun.id
  )

let get_views_for_tune tune_id =
  Connection.with_ @@ fun db ->
  (* FIXME: Rather than getting `All we should get just the ones that we actually care about *)
  let%lwt tune_extra_names_for = get_tune_extra_names_for db `All in
  let%lwt tune_dances_for = get_tune_dances_for db `All in
  let%lwt other_versions_for = get_other_versions_for db `All in
  let%lwt tune_composers_for = get_tune_composers_with_details_for db `All in
  let%lwt arrangers_for = get_arrangers_for db `All in
  let%lwt sources_for = get_version_sources_for db `All in
  Version_sql.List.get_views_for_tune db ~tune_id: (Entry.Id.to_string tune_id) (fun ~id ~tune_id ->
    version_sql_to_view
      ~id
      ~tune_id
      ~arrangers: (arrangers_for id)
      ~sources: (sources_for id)
      ~tune_extra_names: (tune_extra_names_for tune_id)
      ~tune_dances: (tune_dances_for tune_id)
      ~tune_composers: (tune_composers_for tune_id)
      ~tune_versions: (other_versions_for tune_id)
      ~k: Fun.id
  )

let get_form id : Version_form.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt tune_composers_for = get_tune_composers_for db (`One_of [id]) in
  let%lwt arrangers = (fun f -> f id) <$> get_arrangers_for db (`One_of [id]) in
  let%lwt sources = (fun f -> f id) <$> get_version_form_sources_for db (`One_of [id]) in
  let%lwt destructured_parts = (fun f -> f id) <$> get_destructured_parts_for db (`One_of [id]) in
  let%lwt destructured_transitions = (fun f -> f id) <$> get_destructured_transitions_for db (`One_of [id]) in
  Version_sql.Single.get_form db ~id (fun ~id ~tune_id ->
    version_sql_to_form
      ~id
      ~tune_id
      ~arrangers
      ~sources
      ~tune_composers: (tune_composers_for tune_id)
      ~destructured_parts
      ~destructured_transitions
      ~k: Fun.id
  )

let get_all_forms () : Version_form.t list Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt tune_composers_for = get_tune_composers_for db `All in
  let%lwt arrangers_for = get_arrangers_for db `All in
  let%lwt sources_for = get_version_form_sources_for db `All in
  let%lwt destructured_parts_for = get_destructured_parts_for db `All in
  let%lwt destructured_transitions_for = get_destructured_transitions_for db `All in
  Version_sql.List.get_all_forms db (fun ~id ~tune_id ->
    version_sql_to_form
      ~id
      ~tune_id
      ~arrangers: (arrangers_for id)
      ~sources: (sources_for id)
      ~tune_composers: (tune_composers_for tune_id)
      ~destructured_parts: (destructured_parts_for id)
      ~destructured_transitions: (destructured_transitions_for id)
      ~k: Fun.id
  )

let get_content id : Model_builder.Core.Version.Content.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt destructured_parts = (fun f -> f id) <$> get_destructured_parts_for db (`One_of [id]) in
  let%lwt destructured_transitions = (fun f -> f id) <$> get_destructured_transitions_for db (`One_of [id]) in
  Version_sql.Single.get_content db ~id (fun ~id: _ ~monolithic_lilypond ~monolithic_bars ~monolithic_or_default_structure ~destructured_as_2_4 ->
    match (monolithic_lilypond, monolithic_bars), (destructured_parts, destructured_transitions), monolithic_or_default_structure with
    | (None, None), ([], []), None ->
      Model_builder.Core.Version.Content.No_content
    | (Some lilypond, Some bars), ([], []), Some structure ->
      Monolithic {
        lilypond;
        bars = Int64.to_int bars;
        structure = Option.get (Model_builder.Core.Version.Structure.of_string (NEString.of_string_exn structure));
      }
    | (None, None), (parts, transitions), Some default_structure ->
      (
        match NEList.of_list parts with
        | None -> assert false
        | Some parts ->
          Destructured {
            parts;
            transitions;
            default_structure = Option.get (Model_builder.Core.Version.Structure.of_string (NEString.of_string_exn default_structure));
            as_2_4 = destructured_as_2_4;
          }
      )
    | _ -> assert false
  )

let search query : (Version_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = {Version_query.tune; key; source}} = query in
  Connection.with_ @@ fun db ->
  let%lwt tune_composers_for = get_tune_composers_for db `All in
  let%lwt sources_for = get_sources_for db `All in
  let%lwt arrangers_for = get_arrangers_for db `All in
  Version_sql.List.search
    db
    ~terms
    ~key: (Option.map (List.map Music.Key.to_string) key)
    ~source: (Utils.option_to_sql source)
    ~tune_kind: (Option.map (List.map Sql_types.kind_base_of_common) tune.kind)
    ~tune_composer: (Utils.option_to_sql tune.composer)
    (fun ~score ~id ~tune_id ->
      version_sql_to_row
        ~id
        ~tune_id
        ~tune_composers: (tune_composers_for tune_id)
        ~sources: (sources_for id)
        ~arrangers: (arrangers_for id)
        ~k: (Pair.snoc score)
    )

let update_other_tables db ~version_id ~arrangers ~sources ~content =
  ignore <$> Version_sql.delete_all_arrangers db ~version_id;%lwt
  Lwt_list.iter_s
    (fun arranger ->
      ignore <$> Version_sql.add_one_arranger db ~version_id ~arranger_id: arranger.Person_row.id
    )
    arrangers;%lwt
  ignore <$> Version_sql.delete_all_sources db ~version_id;%lwt
  Lwt_list.iter_s
    (fun {Version_form.source; structure; details} ->
      ignore
      <$> Version_sql.add_one_source
          db
          ~version_id
          ~source_id: source.id
          ~structure: (NEString.to_string @@ Model_builder.Core.Version.Structure.to_string structure)
          ~details: (Option.map NEString.to_string details)
    )
    sources;%lwt
  ignore <$> Version_sql.delete_all_destructured_parts db ~version_id;%lwt
  ignore <$> Version_sql.delete_all_destructured_transitions db ~version_id;%lwt
  (
    match content with
    | Model_builder.Core.Version.Content.No_content | Monolithic _ -> lwt_unit
    | Destructured {parts; transitions; default_structure = _; as_2_4 = _} ->
      Lwt_list.iteri_s
        (fun part {Model_builder.Core.Version.Voices.melody; chords} ->
          ignore
          <$> Version_sql.add_one_destructured_part
              db
              ~version_id
              ~part: Model_builder.Core.Version.Part_name.(to_string @@ of_int part)
              ~melody
              ~chords
        )
        (NEList.to_list parts);%lwt
      Lwt_list.iter_s
        (fun (from_parts, to_parts, {Model_builder.Core.Version.Voices.melody; chords}) ->
          ignore
          <$> Version_sql.add_one_destructured_transition
              db
              ~version_id
              ~from_parts: (Model_builder.Core.Version.Part_name.opens_to_string from_parts)
              ~to_parts: (Model_builder.Core.Version.Part_name.opens_to_string to_parts)
              ~melody
              ~chords
        )
        transitions
  )

let create db version =
  let%lwt id = Entry_new.make_public db `Version in
  ignore <$> version_form_to_sql (Version_sql.create db) id version;%lwt
  update_other_tables db ~version_id: id ~arrangers: version.arrangers ~sources: version.sources ~content: version.content;%lwt
  lwt id

let update db id version =
  Entry_new.touch db id;%lwt
  ignore <$> version_form_to_sql (fun ~id -> Version_sql.update db ~id) id version;%lwt
  update_other_tables db ~version_id: id ~arrangers: version.arrangers ~sources: version.sources ~content: version.content

let delete db id =
  ignore <$> Version_sql.delete_all_arrangers db ~version_id: id;%lwt
  ignore <$> Version_sql.delete_all_sources db ~version_id: id;%lwt
  ignore <$> Version_sql.delete_all_destructured_parts db ~version_id: id;%lwt
  ignore <$> Version_sql.delete_all_destructured_transitions db ~version_id: id;%lwt
  ignore <$> Version_sql.delete db ~id;%lwt
  Entry_new.delete db id
