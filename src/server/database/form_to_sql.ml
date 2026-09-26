open Nes
open Dancelor_common
open Model_new

let person_form_to_sql query id {Person_form.name; scddb_id} =
  query
    ~id
    ~name: (NEString.to_string name)
    ~scddb_id: (Option.map Int64.of_int scddb_id)
