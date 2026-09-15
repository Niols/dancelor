open Nes
open Dancelor_common
open Model_new
open Search_new
open Sql_to_name
open Sql_to_row
open Sql_to_view

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

let get_arrangers_for db version_ids =
  Utils.fold_to_get_list (Version_sql.Fold.get_arrangers_for db ~version_ids) (fun k ~version_id -> person_sql_to_name ~k: (k version_id))

let get_other_versions_for db version_ids =
  let%lwt sources_for = Utils.fold_to_get_list (Version_sql.Fold.get_sources_for_other_versions_of db ~version_ids) (fun k ~version_id -> source_sql_to_short_name ~k: (k version_id)) in
  let%lwt arrangers_for = Utils.fold_to_get_list (Version_sql.Fold.get_arrangers_for_other_versions_of db ~version_ids) (fun k ~version_id -> person_sql_to_name ~k: (k version_id)) in
  Utils.fold_to_get_list (Version_sql.Fold.get_other_versions_for db ~version_ids) (fun k ~id ~tune_id -> tune_sql_to_version_row_without_tune ~id ~arrangers: (arrangers_for id) ~sources: (sources_for id) ~k: (k tune_id))

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

(* Legacy *)

type t = Model_builder.Core.Version.t
type entry = Model_builder.Core.Version.entry

let sql_to_version
    ~id
    ~tune_id
    ~key
    ~remark
    ~disambiguation
    ~monolithic_lilypond
    ~monolithic_bars
    ~monolithic_or_default_structure
    ~destructured_as_2_4
    ~created_at
    ~modified_at
    ~arrangers
    ~sources
    ~destructured_parts
    ~destructured_transitions
  =
  let content : Model_builder.Core.Version.Content.t =
    match (monolithic_lilypond, monolithic_bars),
    (destructured_parts, destructured_transitions),
    monolithic_or_default_structure with
    | (None, None), ([], []), None ->
      No_content
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
  in
  Entry.make
    ~id
    ~meta: (Entry.Meta.make ~created_at ~modified_at ())
    ~access: Entry.Access.Public
    (
      Model_builder.Core.Version.make
        ~tune: tune_id
        ~key: (Music.Key.of_string key)
        ~remark: (Option.map NEString.of_string_exn remark)
        ~disambiguation: (Option.map NEString.of_string_exn disambiguation)
        ~sources
        ~arrangers
        ~content
        ()
    )

let version_to_sql ~create_or_update db id version =
  (* FIXME: transaction, maybe [Connection.with_transaction] *)
  let (monolithic_lilypond, monolithic_bars, monolithic_or_default_structure, destructured_as_2_4) =
    match Model_builder.Core.Version.content version with
    | No_content -> (None, None, None, false)
    | Monolithic {lilypond; bars; structure} -> (Some lilypond, Some (Int64.of_int bars), Some (NEString.to_string @@ Model_builder.Core.Version.Structure.to_string structure), false)
    | Destructured {default_structure; as_2_4; _} -> (None, None, Some (NEString.to_string @@ Model_builder.Core.Version.Structure.to_string default_structure), as_2_4)
  in
  ignore
  <$> create_or_update
      db
      ~id
      ~tune_id: (Model_builder.Core.Version.tune version)
      ~key: (Music.Key.to_string @@ Model_builder.Core.Version.key version)
      ~remark: (Option.map NEString.to_string @@ Model_builder.Core.Version.remark version)
      ~disambiguation: (Option.map NEString.to_string @@ Model_builder.Core.Version.disambiguation version)
      ~monolithic_lilypond
      ~monolithic_bars
      ~monolithic_or_default_structure
      ~destructured_as_2_4;%lwt
  ignore <$> Version_sql.delete_all_arrangers db ~version_id: id;%lwt
  Lwt_list.iter_s
    (fun arranger ->
      ignore
      <$> Version_sql.add_one_arranger
          db
          ~version_id: id
          ~arranger_id: arranger
    )
    (Model_builder.Core.Version.arrangers version);%lwt
  ignore <$> Version_sql.delete_all_sources db ~version_id: id;%lwt
  Lwt_list.iter_s
    (fun Model_builder.Core.Version.{source; structure; details} ->
      ignore
      <$> Version_sql.add_one_source
          db
          ~version_id: id
          ~source_id: source
          ~structure: (NEString.to_string @@ Model_builder.Core.Version.Structure.to_string structure)
          ~details: (Option.map NEString.to_string details)
    )
    (Model_builder.Core.Version.sources version);%lwt
  (
    ignore <$> Version_sql.delete_all_destructured_parts db ~version_id: id;%lwt
    ignore <$> Version_sql.delete_all_destructured_transitions db ~version_id: id;%lwt
    match Model_builder.Core.Version.content version with
    | No_content | Monolithic _ -> lwt_unit
    | Destructured {parts; transitions; default_structure = _; as_2_4 = _} ->
      Lwt_list.iteri_s
        (fun part Model_builder.Core.Version.Voices.{melody; chords} ->
          ignore
          <$> Version_sql.add_one_destructured_part
              db
              ~version_id: id
              ~part: Model_builder.Core.Version.Part_name.(to_string @@ of_int part)
              ~melody
              ~chords
        )
        (NEList.to_list parts);%lwt
      Lwt_list.iter_s
        (fun (from_parts, to_parts, Model_builder.Core.Version.Voices.{melody; chords}) ->
          ignore
          <$> Version_sql.add_one_destructured_transition
              db
              ~version_id: id
              ~from_parts: (Model_builder.Core.Version.Part_name.opens_to_string from_parts)
              ~to_parts: (Model_builder.Core.Version.Part_name.opens_to_string to_parts)
              ~melody
              ~chords
        )
        transitions
  )

let check_destructured_parts =
  (* NOTE: A bit weird: on the OCaml side, part names are implicit and just come
     from the order in the list, while in SQL we store the part name/number. SQL
     sorts for us, but now we need to check that they correspond. *)
  List.mapi (fun i (part, voices) ->
    if Model_builder.Core.Version.Part_name.to_int part <> i then assert false
    else voices
  )

let get id : Model_builder.Core.Version.entry option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt arrangers = Version_sql.List.get_arrangers db ~version_id: id (fun ~arranger_id -> arranger_id) in
  let%lwt sources =
    Version_sql.List.get_sources db ~version_id: id (fun ~source_id ~structure ~details ->
      {
        Model_builder.Core.Version.source = source_id;
        structure = Option.get (Model_builder.Core.Version.Structure.of_string (NEString.of_string_exn structure));
        details = Option.map NEString.of_string_exn details;
      }
    )
  in
  let%lwt destructured_parts =
    check_destructured_parts
    <$> (
        Version_sql.List.get_destructured_parts db ~version_id: id (fun ~part ~melody ~chords ->
          (
            Option.get (Model_builder.Core.Version.Part_name.of_string part),
            {Model_builder.Core.Version.Voices.melody; chords}
          )
        )
      )
  in
  let%lwt destructured_transitions =
    Version_sql.List.get_destructured_transitions db ~version_id: id (fun ~from_parts ~to_parts ~melody ~chords ->
      (
        Option.get (Model_builder.Core.Version.Part_name.opens_of_string from_parts),
        Option.get (Model_builder.Core.Version.Part_name.opens_of_string to_parts),
        {Model_builder.Core.Version.Voices.melody; chords}
      )
    )
  in
  Version_sql.Single.get db ~id (sql_to_version ~id ~arrangers ~sources ~destructured_parts ~destructured_transitions)

let get_all () =
  Connection.with_ @@ fun db ->
  let arrangers = Hashtbl.create 8 in
  let sources = Hashtbl.create 8 in
  let destructured_parts = Hashtbl.create 8 in
  let destructured_transitions = Hashtbl.create 8 in
  Version_sql.Fold.get_all_arrangers
    db
    (fun ~version_id ~arranger_id () ->
      Hashtbl.add arrangers version_id arranger_id
    )
    ();%lwt
  Version_sql.Fold.get_all_sources
    db
    (fun ~version_id ~source_id ~structure ~details () ->
      Hashtbl.add
        sources
        version_id
        {
          Model_builder.Core.Version.source = source_id;
          structure = Option.get (Model_builder.Core.Version.Structure.of_string (NEString.of_string_exn structure));
          details = Option.map NEString.of_string_exn details;
        }
    )
    ();%lwt
  Version_sql.Fold.get_all_destructured_parts
    db
    (fun ~version_id ~part ~melody ~chords () ->
      Hashtbl.add destructured_parts version_id (
        Option.get (Model_builder.Core.Version.Part_name.of_string part),
        {Model_builder.Core.Version.Voices.melody; chords}
      )
    )
    ();%lwt
  Version_sql.Fold.get_all_destructured_transitions
    db
    (fun ~version_id ~from_parts ~to_parts ~melody ~chords () ->
      Hashtbl.add
        destructured_transitions
        version_id
        (
          Option.get (Model_builder.Core.Version.Part_name.opens_of_string from_parts),
          Option.get (Model_builder.Core.Version.Part_name.opens_of_string to_parts),
          {Model_builder.Core.Version.Voices.melody; chords}
        )
    )
    ();%lwt
  Version_sql.List.get_all db (fun ~id ->
    sql_to_version
      ~id
      ~arrangers: (List.rev @@ Hashtbl.find_all arrangers id)
      ~sources: (List.rev @@ Hashtbl.find_all sources id)
      ~destructured_parts: (check_destructured_parts @@ List.rev @@ Hashtbl.find_all destructured_parts id)
      ~destructured_transitions: (List.rev @@ Hashtbl.find_all destructured_transitions id)
  )

let get_all_for_tune tune_id =
  Connection.with_ @@ fun db ->
  let arrangers = Hashtbl.create 8 in
  let sources = Hashtbl.create 8 in
  let destructured_parts = Hashtbl.create 8 in
  let destructured_transitions = Hashtbl.create 8 in
  Version_sql.Fold.get_all_arrangers
    db
    (fun ~version_id ~arranger_id () ->
      Hashtbl.add arrangers version_id arranger_id
    )
    ();%lwt
  Version_sql.Fold.get_all_sources
    db
    (fun ~version_id ~source_id ~structure ~details () ->
      Hashtbl.add
        sources
        version_id
        {
          Model_builder.Core.Version.source = source_id;
          structure = Option.get (Model_builder.Core.Version.Structure.of_string (NEString.of_string_exn structure));
          details = Option.map NEString.of_string_exn details;
        }
    )
    ();%lwt
  Version_sql.Fold.get_all_destructured_parts
    db
    (fun ~version_id ~part ~melody ~chords () ->
      Hashtbl.add destructured_parts version_id (
        Option.get (Model_builder.Core.Version.Part_name.of_string part),
        {Model_builder.Core.Version.Voices.melody; chords}
      )
    )
    ();%lwt
  Version_sql.Fold.get_all_destructured_transitions
    db
    (fun ~version_id ~from_parts ~to_parts ~melody ~chords () ->
      Hashtbl.add
        destructured_transitions
        version_id
        (
          Option.get (Model_builder.Core.Version.Part_name.opens_of_string from_parts),
          Option.get (Model_builder.Core.Version.Part_name.opens_of_string to_parts),
          {Model_builder.Core.Version.Voices.melody; chords}
        )
    )
    ();%lwt
  Version_sql.List.get_all_for_tune db ~tune_id (fun ~id ->
    sql_to_version
      ~id
      ~tune_id
      ~arrangers: (List.rev @@ Hashtbl.find_all arrangers id)
      ~sources: (List.rev @@ Hashtbl.find_all sources id)
      ~destructured_parts: (check_destructured_parts @@ List.rev @@ Hashtbl.find_all destructured_parts id)
      ~destructured_transitions: (List.rev @@ Hashtbl.find_all destructured_transitions id)
  )

let create version =
  Connection.with_ @@ fun db ->
  let%lwt id = Entry_new.make_public db `Version in
  version_to_sql ~create_or_update: Version_sql.create db id version;%lwt
  lwt id

let update id version =
  Connection.with_ @@ fun db ->
  Entry_new.touch db id;%lwt
  version_to_sql ~create_or_update: (fun db ~id -> Version_sql.update db ~id) db id version

let delete id =
  Connection.with_ @@ fun db ->
  ignore <$> Version_sql.delete_all_arrangers db ~version_id: id;%lwt
  ignore <$> Version_sql.delete_all_sources db ~version_id: id;%lwt
  ignore <$> Version_sql.delete_all_destructured_parts db ~version_id: id;%lwt
  ignore <$> Version_sql.delete_all_destructured_transitions db ~version_id: id;%lwt
  ignore <$> Version_sql.delete db ~id;%lwt
  Entry_new.delete db id
