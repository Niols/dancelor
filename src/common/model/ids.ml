open Tags

module Person_id = struct
  type t = Person_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module User_id = struct
  type t = User_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module Dance_id = struct
  type t = Dance_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module Source_id = struct
  type t = Source_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module Tune_id = struct
  type t = Tune_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module Version_id = struct
  type t = Version_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module Set_id = struct
  type t = Set_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module Book_id = struct
  type t = Book_tag.t Id.t
  [@@deriving eq, yojson, show {with_path = false}]

  (* For URI serialisation *)
  let to_string = Id.to_string
  let of_string = Id.of_string
end

module Any_id = struct
  module Type = struct
    type t =
      | Person
      | Dance
      | Source
      | Tune
      | Version
      | Set
      | Book
      | User
    [@@deriving eq, yojson, show {with_path = false}]
  end

  type t =
    | Person of Person_id.t
    | Dance of Dance_id.t
    | Source of Source_id.t
    | Tune of Tune_id.t
    | Version of Version_id.t
    | Set of Set_id.t
    | Book of Book_id.t
    | User of User_id.t
  [@@deriving eq, yojson, variants, show {with_path = false}]

  let of_untagged : Type.t -> Untagged.t Id.t -> t = fun type_ id ->
    match type_ with
    | Person -> Person (Id.unsafe_coerce id)
    | Dance -> Dance (Id.unsafe_coerce id)
    | Source -> Source (Id.unsafe_coerce id)
    | Tune -> Tune (Id.unsafe_coerce id)
    | Version -> Version (Id.unsafe_coerce id)
    | Set -> Set (Id.unsafe_coerce id)
    | Book -> Book (Id.unsafe_coerce id)
    | User -> User (Id.unsafe_coerce id)

  let to_untagged : t -> Untagged.t Id.t = function
    | Person x -> Id.unsafe_coerce x
    | Dance x -> Id.unsafe_coerce x
    | Source x -> Id.unsafe_coerce x
    | Tune x -> Id.unsafe_coerce x
    | Version x -> Id.unsafe_coerce x
    | Set x -> Id.unsafe_coerce x
    | Book x -> Id.unsafe_coerce x
    | User x -> Id.unsafe_coerce x
end
