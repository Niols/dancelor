type public = Public [@@deriving eq, show, yojson]

module Private : sig
  type t [@@deriving eq, show, yojson]

  val make : ?owners: User.t Id.t list -> ?viewers: User.t Id.t list -> ?is_public: bool -> unit -> t

  val owners : t -> User.t Id.t list
  val viewers : t -> User.t Id.t list
  val is_public : t -> bool
end
