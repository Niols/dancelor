open Nes

module Witness : sig
    type 'tag t
    val make_unsafe : unit -> 'tag t
  end
= struct
  type 'tag t = Witness
  let make_unsafe () = Witness
end

module type Params = sig
  val module_name : string
end

module Make (Params : Params) = struct
  type t
  let pp _ _ = failwithf "Tags.%s.pp" Params.module_name
  let show _ = failwithf "Tags.%s.show" Params.module_name
  let equal _ _ = failwithf "Tags.%s.equal" Params.module_name
  let to_yojson _ = failwithf "Tags.%s.to_yojson" Params.module_name
  let of_yojson _ = failwithf "Tags.%s.of_yojson" Params.module_name
  let witness : t Witness.t = Witness.make_unsafe ()
end

module Untagged = Make(struct let module_name = "Untagged" end)

module Person_tag = Make(struct let module_name = "Person_tag" end)
module Source_tag = Make(struct let module_name = "Source_tag" end)
module Dance_tag = Make(struct let module_name = "Dance_tag" end)
module Tune_tag = Make(struct let module_name = "Tune_tag" end)
module Version_tag = Make(struct let module_name = "Version_tag" end)
module Set_tag = Make(struct let module_name = "Set_tag" end)
module Book_tag = Make(struct let module_name = "Book_tag" end)
module User_tag = Make(struct let module_name = "User_tag" end)
module Group_tag = Make(struct let module_name = "Group_tag" end)

type ('r, 'p) resource_or_principal =
  | Resource of 'r
  | Principal of 'p

module Resource_type = struct
  type t = [
    | `Person
    | `Dance
    | `Source
    | `Tune
    | `Version
    | `Set
    | `Book
  ]
  [@@deriving eq, yojson, show {with_path = false}]
end

module Principal_type = struct
  type t = [
    | `User
    | `Group
  ]
  [@@deriving eq, yojson, show {with_path = false}]
end

module Entity_type = struct
  type t =
    [Resource_type.t | Principal_type.t]
  [@@deriving eq, yojson, show {with_path = false}]

  let classify : t -> (Resource_type.t, Principal_type.t) resource_or_principal = function
    | `Person -> Resource `Person
    | `Dance -> Resource `Dance
    | `Source -> Resource `Source
    | `Tune -> Resource `Tune
    | `Version -> Resource `Version
    | `Set -> Resource `Set
    | `Book -> Resource `Book
    | `User -> Principal `User
    | `Group -> Principal `Group
end
