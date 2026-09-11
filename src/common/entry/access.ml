type public =
  Public
[@@deriving eq, show, yojson]

module Private = struct
  type t = {
    owners: User.t Id.t list; [@default []]
    viewers: User.t Id.t list; [@default []]
    is_public: bool; [@default false]
  }
  [@@deriving eq, make, show, fields, yojson]
end
