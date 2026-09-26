open Nes
open Dancelor_common
open Model_new

let person_sql_to_form ~id: _ ~name ~scddb_id ~(k : Person_form.t -> 'w) : 'w =
  k {
    name = NEString.of_string_exn name;
    scddb_id = Option.map Int64.to_int scddb_id;
  }
