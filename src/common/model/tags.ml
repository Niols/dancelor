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
