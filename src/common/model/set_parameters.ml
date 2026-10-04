(** {1 Set Parameters}

    This module defines parameters that make sense at the level of a set. This
    includes version parameters as well. *)

open Nes

module Self = struct
  type t = {
    display_name: NEString.t option; [@default None] [@key "display-name"]
    display_conceptor: NEString.t option; [@default None] [@key "display-conceptor"]
    display_kind: NEString.t option; [@default None] [@key "display-kind"]
    every_version: Version_parameters.t [@default Version_parameters.none] [@key "every-version"]
  }
  [@@deriving eq, ord, make, show {with_path = false}, yojson, fields]
end
include Self

(* FIXME: see remark in Version_parameters *)
let make ?display_name ?display_conceptor ?display_kind ?every_version () =
  make ~display_name ~display_conceptor ~display_kind ?every_version ()

(** {2 Defaults}

    Getters that end with a quote are getters that have a default value. *)

let none = `Assoc [] |> of_yojson |> Result.get_ok

(** {2 Composition} *)

let compose first second = {
  display_name = Option.(choose ~tie: second) first.display_name second.display_name;
  display_conceptor = Option.(choose ~tie: second) first.display_conceptor second.display_conceptor;
  display_kind = Option.(choose ~tie: second) first.display_kind second.display_kind;
  every_version = Version_parameters.compose first.every_version second.every_version
}
