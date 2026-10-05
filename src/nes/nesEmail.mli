type t
[@@deriving eq, yojson]

val of_string : string -> t option

val of_string_exn : string -> t

val to_string : t -> string
