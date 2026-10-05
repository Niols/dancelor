open Nes
open Dancelor_common

let person_form_to_sql query id {Person_form.name; scddb_id} =
  query
    ~id
    ~name: (NEString.to_string name)
    ~scddb_id: (Option.map Int64.of_int scddb_id)

let source_form_to_sql query id {Source_form.name; short_name; scddb_id; description; date; editors = _} =
  query
    ~id
    ~name: (NEString.to_string name)
    ~short_name: (Option.map NEString.to_string short_name)
    ~scddb_id: (Option.map Int64.of_int scddb_id)
    ~description
    ~date: (Option.map PartialDate.to_string date)

let dance_form_to_sql query id {Dance_form.names; kind; two_chords; scddb_id; disambiguation; date; devisers = _} =
  query
    ~id
    ~name: (NEString.to_string @@ NEList.hd names)
    ~kind: (Kind.Dance.to_string kind)
    ~two_chords
    ~scddb_id: (Option.map Int64.of_int scddb_id)
    ~disambiguation: (Option.map NEString.to_string disambiguation)
    ~date: (Option.map PartialDate.to_string date)

let tune_form_to_sql
    query
    id
    {
      Tune_form.names;
      kind;
      remark;
      scddb_id;
      date;
      composers = _;
      dances = _;
    }
  =
  query
    ~id
    ~name: (NEString.to_string @@ NEList.hd names)
    ~kind
    ~remark: (Option.map NEString.to_string remark)
    ~scddb_id: (Option.map Int64.of_int scddb_id)
    ~date: (Option.map PartialDate.to_string date)

let version_form_to_sql
    query
    id
    {
      Version_form.tune;
      key;
      remark;
      disambiguation;
      content;
      sources = _;
      arrangers = _;
    }
  =
  let (monolithic_lilypond, monolithic_bars, monolithic_or_default_structure, destructured_as_2_4) =
    match content with
    | No_content -> (None, None, None, false)
    | Monolithic {lilypond; bars; structure} -> (Some lilypond, Some (Int64.of_int bars), Some (NEString.to_string @@ Version_content.Structure.to_string structure), false)
    | Destructured {default_structure; as_2_4; _} -> (None, None, Some (NEString.to_string @@ Version_content.Structure.to_string default_structure), as_2_4)
  in
  query
    ~id
    ~tune_id: tune.id
    ~key: (Music.Key.to_string key)
    ~remark: (Option.map NEString.to_string remark)
    ~disambiguation: (Option.map NEString.to_string disambiguation)
    ~monolithic_lilypond
    ~monolithic_bars
    ~monolithic_or_default_structure
    ~destructured_as_2_4

let set_form_to_sql
    query
    id
    {
      Set_form.name;
      kind;
      order;
      conceptors = _;
      contents = _;
    }
  =
  query
    ~id
    ~name: (NEString.to_string name)
    ~kind: (Kind.Dance.to_string kind)
    ~order: (Set_order.to_string order)

let book_form_to_sql
    query
    id
    {
      Book_form.name;
      date;
      remark;
      scddb_id;
      authors = _;
      contents = _;
      sources = _;
    }
  =
  query
    ~id
    ~name: (NEString.to_string name)
    ~date: (Option.map PartialDate.to_string date)
    ~remark: (Option.map NEString.to_string remark)
    ~scddb_id: (Option.map Int64.of_int scddb_id)
