(** {1 Entry.Id}

    Global identifier for Dancelor's database. They are composed of three groups
    of four alphanumerical characters, one of which is a control sum. This makes
    for 36 ** 11, ie. over 10 ** 17 or over 2 ** 56 ids. *)

(** Type of ids carrying values of type ['value]. *)
type 'value t
[@@deriving yojson]

val make : unit -> 'value t
(** Make a new random id. *)

val equal : ('value -> 'value -> bool) -> 'value t -> 'value t -> bool
(** For compatibility with [ppx_deriving.std]'s [equal]. Prefer {!equal'}. *)

val compare : ('value -> 'value -> int) -> 'value t -> 'value t -> int
(** For compatibility with [ppx_deriving.std]'s [compare]. Prefer {!compare'}. *)

val equal' : 'value t -> 'value t -> bool
val compare' : 'value t -> 'value t -> int

val of_string : string -> 'value t option
(** Creates an id from the given string, or returns [None] if the given string
    is not a valid id. *)

val of_string_exn : string -> 'value t
(** Creates an id from the given string. This function fails with
    [Invalid_argument _] if the given string is not a valid id. *)

val to_string : 'value t -> string
(** Returns a string representing the id. *)

val of_yojson' : Yojson.Safe.t -> ('value t, string) result

val to_yojson' : 'value t -> Yojson.Safe.t

val pp : (Format.formatter -> 'value -> unit) -> Format.formatter -> 'value t -> unit
(** For debugging purposes with [ppx_deriving_show]. Prefer {!pp'}. *)

val pp' : Format.formatter -> 'value t -> unit

(** {2 Low-level and Unsafe} *)

val unsafe_coerce : 'value t -> 'new_value t
(** Loses the type information from the id. *)

val unsafe_equal : 'value t -> 'other_value t -> bool
(** Compare while losing type information. *)

(** {2 Serialisation} *)

module type TYPEABLE = sig type t end

module S (A : TYPEABLE) : Madge.STRINGABLE with type t = A.t t

module J (A : TYPEABLE) : Madge.JSONABLE with type t = A.t t
