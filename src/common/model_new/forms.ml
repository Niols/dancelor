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
