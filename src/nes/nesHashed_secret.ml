(* This module only exists to expose the type of hashed secrets everywhere, but
   the interesting stuff lives in [NesHashedSecretUnix]. *)

type t = string
[@@deriving show, eq, ord, yojson]

let unsafe_of_string = Fun.id
let unsafe_to_string = Fun.id
