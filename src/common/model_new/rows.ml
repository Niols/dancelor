open Nes
open Ids
open Names

module Person_row = struct
  type t = Person_name.t = {
    id: Person_id.t;
    name: string;
  }
  [@@deriving yojson, fields]
end

module User_row = struct
  type t = {
    id: User_id.t;
    username: Username.t;
  }
  [@@deriving yojson, fields]
end

module Dance_row = struct
  type t = {
    id: Dance_id.t;
    name: string;
    kind: Kind_dance.t;
    devisers: Person_name.t list; [@default []]
    disambiguation: string option; [@default None]
  }
  [@@deriving yojson, fields]

  let to_name : t -> Dance_name.t = fun {id; name; _} -> {id; name}
end

module Source_row = struct
  type t = {
    id: Source_id.t;
    name: string;
    date: PartialDate.t option; [@default None]
    editors: Person_name.t list; [@default []]
  }
  [@@deriving yojson, fields]

  let to_name : t -> Source_name.t = fun {id; name; _} -> {id; name}
end

module Tune_row = struct
  type t = {
    id: Tune_id.t;
    name: string;
    kind: Kind_base.t;
    composers: Person_name.t list; [@default []]
  }
  [@@deriving yojson, fields]

  let to_name : t -> Tune_name.t = fun {id; name; _} -> {id; name}
end

module Version_row = struct
  type content =
    | No_content
    | Destructured
    | Monolithic of {bars: int; structure: Model_builder.Core.Version.Structure.t}
  [@@deriving yojson]

  type t = {
    id: Version_id.t;
    tune: Tune_row.t;
    sources: Source_short_name.t list; [@default []]
    disambiguation: string option; [@default None]
    arrangers: Person_name.t list; [@default []]
    content: content;
  }
  [@@deriving yojson, fields]

  let to_name : t -> Version_name.t = fun {id; tune; _} -> {id; name = tune.name}
end

module Set_row = struct
  type t = {
    id: Set_id.t;
    name: string;
    kind: Kind_dance.t;
    conceptors: Person_name.t list; [@default []]
    tunes: Version_name.t list; [@default []]
    permission: Permission_new.t;
  }
  [@@deriving yojson, fields]

  let to_name : t -> Set_name.t = fun {id; name; _} -> {id; name}
end

module Book_row = struct
  type t = {
    id: Book_id.t;
    name: string;
    date: PartialDate.t option; [@default None]
    authors: Person_name.t list; [@default []]
    permission: Permission_new.t;
  }
  [@@deriving yojson, fields]
end

module Any_row = struct
  type t =
    | Person of Person_row.t
    | Dance of Dance_row.t
    | Source of Source_row.t
    | Tune of Tune_row.t
    | Version of Version_row.t
    | Set of Set_row.t
    | Book of Book_row.t
    | User of User_row.t
  [@@deriving yojson, variants]

  let to_id : t -> Any_id.t = function
    | Person p -> Person p.id
    | Dance d -> Dance d.id
    | Source s -> Source s.id
    | Tune t -> Tune t.id
    | Version v -> Version v.id
    | Set s -> Set s.id
    | Book b -> Book b.id
    | User u -> User u.id

  let equal a1 a2 = Any_id.equal (to_id a1) (to_id a2)
end
