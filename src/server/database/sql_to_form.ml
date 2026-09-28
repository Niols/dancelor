open Nes
open Dancelor_common
open Model_new

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
    date = Option.map (Option.get % PartialDate.from_string) date;
  }

let dance_sql_to_form ~id: _ ~name ~extra_names ~kind ~devisers ~scddb_id ~disambiguation ~date ~two_chords ~(k : Dance_form.t -> 'w) : 'w =
  k {
    names = NEList.map NEString.of_string_exn (NEList.cons name extra_names);
    kind = Kind_dance.of_string kind;
    devisers;
    scddb_id = Option.map Int64.to_int scddb_id;
    disambiguation = Option.map NEString.of_string_exn disambiguation;
    date = Option.map (Option.get % PartialDate.from_string) date;
    two_chords = Sql_types.two_chords_to_common two_chords;
  }
