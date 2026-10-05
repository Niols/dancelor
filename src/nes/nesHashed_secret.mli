(** {1 Hashed secret}

    High-level utilities to manipulate hashed secrets safely. This can be used
    for passwords and tokens, for instance. *)

type t [@@deriving eq, ord, show, yojson]
(** Abstract type of a hashed secret. *)

(** {2 Utilities} *)

(**/**)
val unsafe_of_string : string -> t
val unsafe_to_string : t -> string
