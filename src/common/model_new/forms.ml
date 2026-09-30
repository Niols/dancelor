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

module Version_form = struct
  type source = {
    source: Source_row.t;
    structure: Model_builder.Core.Version.Structure.t;
    details: NEString.t option;
  }
  [@@deriving eq, yojson]

  let source_to_short_name {source = {id; name; _}; _} : Source_short_name.t = {
    id;
    short_name = name; (* FIXME: that's bad *)
  }

  type t = {
    tune: Tune_row.t;
    key: Music.Key.t;
    sources: source list;
    arrangers: Person_row.t list;
    remark: NEString.t option;
    disambiguation: NEString.t option;
    content: Model_builder.Core.Version.Content.t;
  }
  [@@deriving eq, yojson]

  let to_name id {tune; _} : Version_name.t =
    {id; name = tune.name}

  let content_to_row_content : Model_builder.Core.Version.Content.t -> Version_row.content = function
    | No_content -> No_content
    | Destructured _ -> Destructured
    | Monolithic {lilypond = _; bars; structure} -> Monolithic {bars; structure}

  let to_row id {tune; sources; disambiguation; arrangers; content; _} : Version_row.t = {
    id;
    tune;
    sources = List.map source_to_short_name sources;
    disambiguation = Option.map NEString.to_string disambiguation;
    arrangers;
    content = content_to_row_content content;
  }
end

module Set_form = struct
  type t = {
    name: NEString.t;
    kind: Kind.Dance.t;
    conceptors: Person_row.t list;
    contents: (Version_row.t * Model_builder.Core.Version_parameters.t) list;
    order: Model_builder.Core.Set_order.t;
  }
  [@@deriving eq, yojson]

  let to_name id {name; _} : Set_name.t =
    {id; name = NEString.to_string name}

  let to_row id {name; kind; conceptors; contents; _} : Set_row.t =
    let tunes = List.map (Version_row.to_name % fst) contents in
    (* FIXME: grab proper permissions from somewhere, maybe pass to [to_row] *)
    let permission = {Permission_new.entry_is_public = false; actor_role = None; actor_is_omniscient_administrator = false} in
      {id; name = NEString.to_string name; kind; conceptors; tunes; permission}
end
