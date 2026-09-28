open Nes
open Dancelor_common
open Model_new

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
    ~kind: (Kind_dance.to_string kind)
    ~two_chords: (Sql_types.two_chords_of_common two_chords)
    ~scddb_id: (Option.map Int64.of_int scddb_id)
    ~disambiguation: (Option.map NEString.to_string disambiguation)
    ~date: (Option.map PartialDate.to_string date)

let tune_form_to_sql query id {Tune_form.names; kind; remark; scddb_id; date; composers = _; dances = _} =
  query
    ~id
    ~name: (NEString.to_string @@ NEList.hd names)
    ~kind: (Sql_types.kind_base_of_common kind)
    ~remark: (Option.map NEString.to_string remark)
    ~scddb_id: (Option.map Int64.of_int scddb_id)
    ~date: (Option.map PartialDate.to_string date)
