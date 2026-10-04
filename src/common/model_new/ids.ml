module Person_id = struct
  type t = Model_builder.Core.Person.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module User_id = struct
  type t = Model_builder.Core.User.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module Dance_id = struct
  type t = Model_builder.Core.Dance.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module Source_id = struct
  type t = Model_builder.Core.Source.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module Tune_id = struct
  type t = Model_builder.Core.Tune.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module Version_id = struct
  type t = Model_builder.Core.Version.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module Set_id = struct
  type t = Model_builder.Core.Set.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module Book_id = struct
  type t = Model_builder.Core.Book.t Entry.id
  [@@deriving eq, yojson]

  (* For URI serialisation *)
  let to_string = Entry.Id.to_string
  let of_string = Entry.Id.of_string
end

module Any_id = struct
  type t =
    | Person of Person_id.t
    | Dance of Dance_id.t
    | Source of Source_id.t
    | Tune of Tune_id.t
    | Version of Version_id.t
    | Set of Set_id.t
    | Book of Book_id.t
    | User of User_id.t
  [@@deriving yojson, variants]

  let of_type id : Model_builder.Core.Any.Type.t -> t = function
    | Person -> Person (Entry.Id.unsafe_coerce id)
    | Dance -> Dance (Entry.Id.unsafe_coerce id)
    | Source -> Source (Entry.Id.unsafe_coerce id)
    | Tune -> Tune (Entry.Id.unsafe_coerce id)
    | Version -> Version (Entry.Id.unsafe_coerce id)
    | Set -> Set (Entry.Id.unsafe_coerce id)
    | Book -> Book (Entry.Id.unsafe_coerce id)
    | User -> User (Entry.Id.unsafe_coerce id)

  let equal any1 any2 =
    match any1, any2 with
    | Person id1, Person id2 -> Entry.Id.equal' id1 id2
    | Dance id1, Dance id2 -> Entry.Id.equal' id1 id2
    | Source id1, Source id2 -> Entry.Id.equal' id1 id2
    | Tune id1, Tune id2 -> Entry.Id.equal' id1 id2
    | Version id1, Version id2 -> Entry.Id.equal' id1 id2
    | Set id1, Set id2 -> Entry.Id.equal' id1 id2
    | Book id1, Book id2 -> Entry.Id.equal' id1 id2
    | User id1, User id2 -> Entry.Id.equal' id1 id2
    | _ -> false

  let to_entry_id = function
    | Person x -> Entry.Id.unsafe_coerce x
    | Dance x -> Entry.Id.unsafe_coerce x
    | Source x -> Entry.Id.unsafe_coerce x
    | Tune x -> Entry.Id.unsafe_coerce x
    | Version x -> Entry.Id.unsafe_coerce x
    | Set x -> Entry.Id.unsafe_coerce x
    | Book x -> Entry.Id.unsafe_coerce x
    | User x -> Entry.Id.unsafe_coerce x
end
