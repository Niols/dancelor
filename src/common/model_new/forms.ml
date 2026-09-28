open Nes
open Names
open Rows

module With_id = struct
  type ('id, 'form) t = {
    id: 'id;
    form: 'form;
  }
  [@@deriving fields, yojson]

  let map f {id; form} = f id form
end

module Person_form = struct
  type t = {
    name: NEString.t;
    scddb_id: int option;
  }
  [@@deriving eq, yojson]

  let to_name id {name; _} : Person_name.t =
    {id; name = NEString.to_string name}

  let to_row id {name; _} : Person_row.t =
    {id; name = NEString.to_string name}
end

module Source_form = struct
  type t = {
    name: NEString.t;
    short_name: NEString.t option;
    editors: Person_row.t list;
    scddb_id: int option;
    description: string option;
    date: PartialDate.t option;
  }
  [@@deriving eq, yojson]

  let to_name id {name; _} : Source_name.t =
    {id; name = NEString.to_string name}

  let to_row id {name; date; editors; _} : Source_row.t = {
    id;
    name = NEString.to_string name;
    date;
    editors;
  }
end

module Dance_form = struct
  type t = {
    names: NEString.t NEList.t;
    kind: Kind.Dance.t;
    devisers: Person_row.t list;
    two_chords: Model_builder.Core.Dance.two_chords;
    scddb_id: int option;
    disambiguation: NEString.t option;
    date: PartialDate.t option;
  }
  [@@deriving eq, yojson]

  let to_name id {names; _} : Dance_name.t =
    {id; name = NEString.to_string (NEList.hd names)}

  let to_row id {names; kind; devisers; disambiguation; _} : Dance_row.t = {
    id;
    name = NEString.to_string (NEList.hd names);
    kind;
    devisers;
    disambiguation = Option.map NEString.to_string disambiguation;
  }
end

module Tune_form = struct
  type composer = {
    composer: Person_row.t;
    details: NEString.t option;
  }
  [@@deriving eq, yojson]

  type t = {
    names: NEString.t NEList.t;
    kind: Kind.Base.t;
    composers: composer list;
    dances: Dance_row.t list;
    remark: NEString.t option;
    scddb_id: int option;
    date: PartialDate.t option;
  }
  [@@deriving eq, yojson]

  let to_name id {names; _} : Tune_name.t =
    {id; name = NEString.to_string (NEList.hd names)}

  let to_row id {names; kind; composers; _} : Tune_row.t = {
    id;
    name = NEString.to_string (NEList.hd names);
    kind;
    composers = List.map (fun {composer; _} -> composer) composers;
  }
end
