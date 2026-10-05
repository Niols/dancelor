open Nes
open Dancelor_common
open Sql_to_row

let person_sql_to_form ~id: _ ~name ~scddb_id ~(k : Person_form.t -> 'w) : 'w =
  k {
    name = NEString.of_string_exn name;
    scddb_id = Option.map Int64.to_int scddb_id;
  }

let source_sql_to_form ~id: _ ~name ~short_name ~editors ~scddb_id ~description ~date ~(k : Source_form.t -> 'w) : 'w =
  k {
    name = NEString.of_string_exn name;
    short_name = Option.map NEString.of_string_exn short_name;
    editors;
    scddb_id = Option.map Int64.to_int scddb_id;
    description;
    date = Option.map (Option.get % Partial_date.from_string) date;
  }

let dance_sql_to_form ~id: _ ~name ~extra_names ~kind ~devisers ~scddb_id ~disambiguation ~date ~two_chords ~(k : Dance_form.t -> 'w) : 'w =
  k {
    names = NEList.map NEString.of_string_exn (NEList.cons name extra_names);
    kind = Kind.Dance.of_string kind;
    devisers;
    scddb_id = Option.map Int64.to_int scddb_id;
    disambiguation = Option.map NEString.of_string_exn disambiguation;
    date = Option.map (Option.get % Partial_date.from_string) date;
    two_chords;
  }

let tune_sql_to_form ~id: _ ~name ~extra_names ~kind ~composers ~dances ~remark ~scddb_id ~date ~(k : Tune_form.t -> 'w) : 'w =
  k {
    names = NEList.map NEString.of_string_exn (NEList.cons name extra_names);
    kind;
    composers;
    dances;
    remark = Option.map NEString.of_string_exn remark;
    scddb_id = Option.map Int64.to_int scddb_id;
    date = Option.map (Option.get % Partial_date.from_string) date;
  }

let version_sql_to_form_source
    ~id
    ~name
    ~date
    ~editors
    ~structure
    ~details
    ~(k : Version_form.source -> 'w)
    : 'w
  =
  k {
    source = source_sql_to_row ~id ~name ~date ~editors ~k: Fun.id;
    structure = Option.get (Version_content.Structure.of_string (NEString.of_string_exn structure));
    details = Option.map NEString.of_string_exn details;
  }

let version_sql_to_form
    ~id: _
    ~tune_id
    ~disambiguation
    ~key
    ~remark
    ~monolithic_bars
    ~monolithic_or_default_structure
    ~monolithic_lilypond
    ~destructured_parts
    ~destructured_transitions
    ~destructured_as_2_4
    ~sources
    ~arrangers
    ~tune_name
    ~tune_kind
    ~tune_composers
    ~(k : Version_form.t -> 'w)
    : 'w
  =
  let content : Version_content.t =
    match (monolithic_bars, monolithic_or_default_structure, monolithic_lilypond) with
    | (None, None, None) -> No_content
    | (None, Some default_structure, None) ->
      Destructured {
        default_structure =
        Option.get (Version_content.Structure.of_string (NEString.of_string_exn default_structure));
        parts = NEList.of_list_exn destructured_parts;
        transitions = destructured_transitions;
        as_2_4 = destructured_as_2_4;
      }
    | (Some bars, Some structure, Some monolithic_lilypond) ->
      Monolithic {
        lilypond = monolithic_lilypond;
        bars = Int64.to_int bars;
        structure = Option.get (Version_content.Structure.of_string (NEString.of_string_exn structure));
      }
    | _ -> assert false
  in
  k {
    tune =
    tune_sql_to_row
      ~id: tune_id
      ~name: tune_name
      ~kind: tune_kind
      ~composers: tune_composers
      ~k: Fun.id;
    key = Music.Key.of_string key;
    sources;
    remark = Option.map NEString.of_string_exn remark;
    disambiguation = Option.map NEString.of_string_exn disambiguation;
    arrangers;
    content;
  }

let set_sql_to_form
    ~id: _
    ~name
    ~kind
    ~conceptors
    ~contents
    ~order
    ~(k : Set_form.t -> 'w)
    : 'w
  =
  k {
    name = NEString.of_string_exn name;
    kind = Kind.Dance.of_string kind;
    conceptors;
    contents;
    order = Set_order.of_string order;
  }

let book_sql_to_form
    ~id: _
    ~name
    ~date
    ~authors
    ~contents
    ~remark
    ~sources
    ~scddb_id
    ~(k : Book_form.t -> 'w)
    : 'w
  =
  k {
    name = NEString.of_string_exn name;
    date = Option.map (Option.get % Partial_date.from_string) date;
    authors;
    contents;
    remark = Option.map NEString.of_string_exn remark;
    sources;
    scddb_id = Option.map Int64.to_int scddb_id;
  }
