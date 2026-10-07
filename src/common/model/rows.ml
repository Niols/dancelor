open Nes
open Tags
open Ids
open Names

module Person_row = struct
  type t = Person_name.t = {
    id: Person_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name = Fun.id
end

module User_row = struct
  type t = {
    id: User_id.t;
    username: Username.t;
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> User_name.t = fun {id; username} ->
    {id; username = Username.to_string username}
end

module Group_row = struct
  type t = {
    id: Group_id.t;
    name: string;
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> Group_name.t = fun {id; name} -> {id; name}
end

module Dance_row = struct
  type t = {
    id: Dance_id.t;
    name: string;
    kind: Kind_dance.t;
    devisers: Person_name.t list; [@default []]
    disambiguation: string option; [@default None]
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> Dance_name.t = fun {id; name; _} -> {id; name}
end

module Source_row = struct
  type t = {
    id: Source_id.t;
    name: string;
    date: Partial_date.t option; [@default None]
    editors: Person_name.t list; [@default []]
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> Source_name.t = fun {id; name; _} -> {id; name}
end

module Tune_row = struct
  type t = {
    id: Tune_id.t;
    name: string;
    kind: Kind_base.t;
    composers: Person_name.t list; [@default []]
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> Tune_name.t = fun {id; name; _} -> {id; name}
end

module Version_row = struct
  type content =
    | No_content
    | Destructured
    | Monolithic of {bars: int; structure: Version_content.Structure.t}
  [@@deriving eq, yojson, show {with_path = false}]

  type t = {
    id: Version_id.t;
    tune: Tune_row.t;
    sources: Source_short_name.t list; [@default []]
    disambiguation: string option; [@default None]
    arrangers: Person_name.t list; [@default []]
    content: content;
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> Version_name.t = fun {id; tune; _} -> {id; name = tune.name}
end

module Set_row = struct
  type t = {
    id: Set_id.t;
    name: string;
    kind: Kind_dance.t;
    conceptors: Person_name.t list; [@default []]
    tunes: Version_name.t list; [@default []]
    permission: Permission.t;
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> Set_name.t = fun {id; name; _} -> {id; name}
end

module Book_row = struct
  type t = {
    id: Book_id.t;
    name: string;
    date: Partial_date.t option; [@default None]
    authors: Person_name.t list; [@default []]
    permission: Permission.t;
  }
  [@@deriving eq, yojson, fields, show {with_path = false}]

  let to_name : t -> Book_name.t = fun {id; name; _} ->
    {id; name}
end

module Resource_row = struct
  type t = [
    | `Person of Person_row.t
    | `Dance of Dance_row.t
    | `Source of Source_row.t
    | `Tune of Tune_row.t
    | `Version of Version_row.t
    | `Set of Set_row.t
    | `Book of Book_row.t
  ]
  [@@deriving eq, yojson, variants, show {with_path = false}]

  let to_id : t -> Resource_id.t = function
    | `Person p -> `Person p.id
    | `Dance d -> `Dance d.id
    | `Source s -> `Source s.id
    | `Tune t -> `Tune t.id
    | `Version v -> `Version v.id
    | `Set s -> `Set s.id
    | `Book b -> `Book b.id
end

module Principal_row = struct
  type t = [
    | `User of User_row.t
    | `Group of Group_row.t
  ]
  [@@deriving eq, yojson, variants, show {with_path = false}]

  let to_id : t -> Principal_id.t = function
    | `User u -> `User u.id
    | `Group g -> `Group g.id
end

module Entity_row = struct
  type t =
    [Principal_row.t | Resource_row.t]
  [@@deriving eq, yojson, show {with_path = false}]

  let classify : t -> (Resource_row.t, Principal_row.t) resource_or_principal = function
    | `Person x -> Resource (`Person x)
    | `Dance x -> Resource (`Dance x)
    | `Source x -> Resource (`Source x)
    | `Tune x -> Resource (`Tune x)
    | `Version x -> Resource (`Version x)
    | `Set x -> Resource (`Set x)
    | `Book x -> Resource (`Book x)
    | `User x -> Principal (`User x)
    | `Group x -> Principal (`Group x)
end
