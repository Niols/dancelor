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
