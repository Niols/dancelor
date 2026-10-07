open Nes
open Dancelor_common

let person_sql_to_view ~id ~name ~scddb_id ~composed_tunes_are_public ~published_tunes_are_public ~(k : Person_view.t -> 'w) : 'w =
  k {
    id;
    name;
    scddb_id = Option.map Int64.to_int scddb_id;
    composed_tunes_are_public;
    published_tunes_are_public;
  }

let source_sql_to_view ~id ~name ~short_name ~editors ~scddb_id ~description ~date ~(k : Source_view.t -> 'w) : 'w =
  k {
    id;
    name;
    short_name;
    editors;
    scddb_id = Option.map Int64.to_int scddb_id;
    description;
    date = Option.map (Option.get % Partial_date.from_string) date;
  }

let dance_sql_to_view ~id ~name ~extra_names ~kind ~devisers ~scddb_id ~disambiguation ~date ~two_chords ~tunes ~(k : Dance_view.t -> 'w) : 'w =
  k {
    id;
    name;
    extra_names;
    kind = Kind.Dance.of_string kind;
    devisers;
    scddb_id = Option.map Int64.to_int scddb_id;
    disambiguation;
    date = Option.map (Option.get % Partial_date.from_string) date;
    two_chords;
    tunes;
  }

let tune_sql_to_version_row_without_tune ~id ~sources ~disambiguation ~arrangers ~monolithic_bars ~monolithic_or_default_structure ~(k : Tune_view.version_row_without_tune -> 'w) : 'w =
  let content : Version_row.content =
    match (monolithic_bars, monolithic_or_default_structure) with
    | (None, None) -> No_content
    | (None, Some _default_structure) -> Destructured
    | (Some bars, Some structure) ->
      Monolithic {
        bars = Int64.to_int bars;
        structure = Option.get (Version_content.Structure.of_string (NEString.of_string_exn structure));
      }
    | _ -> assert false
  in
  k {
    id;
    sources;
    disambiguation;
    arrangers;
    content;
  }

let tune_sql_to_view ~id ~name ~extra_names ~kind ~composers ~dances ~remark ~scddb_id ~date ~versions ~(k : Tune_view.t -> 'w) : 'w =
  k {
    id;
    name;
    extra_names;
    kind;
    composers;
    dances;
    remark;
    scddb_id = Option.map Int64.to_int scddb_id;
    date = Option.map (Option.get % Partial_date.from_string) date;
    versions;
  }

let version_sql_to_source
    ~id
    ~name
    ~structure
    ~details
    ~(k : Version_view.source -> 'w)
    : 'w
  =
  k {
    id;
    name;
    structure = Option.get (Version_content.Structure.of_string (NEString.of_string_exn structure));
    details;
  }

let version_sql_to_view
    ~id
    ~tune_id
    ~disambiguation
    ~key
    ~remark
    ~monolithic_bars
    ~monolithic_or_default_structure
    ~sources
    ~arrangers
    ~tune_name
    ~tune_kind
    ~tune_extra_names
    ~tune_dances
    ~tune_composers
    ~tune_versions
    ~tune_remark
    ~tune_scddb_id
    ~tune_date
    ~(k : Version_view.t -> 'w)
    : 'w
  =
  let content : Version_view.content =
    match (monolithic_bars, monolithic_or_default_structure) with
    | (None, None) -> No_content
    | (None, Some default_structure) ->
      Destructured {
        default_structure =
        Option.get (Version_content.Structure.of_string (NEString.of_string_exn default_structure));
      }
    | (Some bars, Some structure) ->
      Monolithic {
        bars = Int64.to_int bars;
        structure = Option.get (Version_content.Structure.of_string (NEString.of_string_exn structure));
      }
    | _ -> assert false
  in
  k {
    id;
    tune =
    tune_sql_to_view
      ~id: tune_id
      ~name: tune_name
      ~extra_names: tune_extra_names
      ~kind: tune_kind
      ~composers: tune_composers
      ~dances: tune_dances
      ~remark: tune_remark
      ~scddb_id: tune_scddb_id
      ~date: tune_date
      ~versions: tune_versions
      ~k: Fun.id;
    key = Music.Key.of_string key;
    sources;
    remark;
    disambiguation;
    arrangers;
    content;
  }

let set_sql_to_view
    ~id
    ~entity_is_public
    ~actor_role
    ~actor_is_omniscient_administrator
    ~name
    ~kind
    ~conceptors
    ~content
    ~order
    ~remark
    ~(k : Set_view.t -> 'w)
    : 'w
  =
  k {
    id;
    name;
    kind = Kind.Dance.of_string kind;
    conceptors;
    content; (* (Version_row.t * Model_builder.Core.Version_parameters.t) list *)
    order = Set_order.of_string order;
    remark;
    permission = {entity_is_public; actor_role; actor_is_omniscient_administrator};
  }

let book_sql_to_view
    ~id
    ~entity_is_public
    ~actor_role
    ~actor_is_omniscient_administrator
    ~name
    ~date
    ~authors
    ~contents
    ~remark
    ~sources
    ~scddb_id
    ~(k : Book_view.t -> 'w)
    : 'w
  =
  k {
    id;
    name;
    date = Option.map (Option.get % Partial_date.from_string) date;
    authors;
    contents;
    remark;
    sources;
    scddb_id = Option.map Int64.to_int scddb_id;
    warnings = [];
    permission = {entity_is_public; actor_role; actor_is_omniscient_administrator};
  }

let user_sql_to_view
    ~id
    ~username
    ~joined
    ~(k : User_view.t -> 'w)
    : 'w
  =
  k {
    id;
    username = Username.of_string_exn username;
    joined
  }

let group_sql_to_view
    ~id
    ~name
    ~members
    ~(k : Group_view.t -> 'w)
    : 'w
  =
  k {
    id;
    name;
    members;
  }
