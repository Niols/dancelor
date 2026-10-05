(** {1 Datetime} *)

type t [@@deriving eq, ord, yojson]

val of_string : string -> t option
val of_string_exn : string -> t
(** Parses an ISO 8601 datetime string. *)

val to_string : t -> string
(** Prints the date and time as an ISO 8601 string. *)

val pp : Format.formatter -> t -> unit
(** See {!to_string}. *)

val now : unit -> t
(** Returns the current date and time. *)

val diff : t -> t -> float
(** Number of seconds between two datetimes. *)

val make_in_the_past : float -> t
(** Make a datetime in the past by the given number of seconds. *)

val make_in_the_future : float -> t
(** Make a datetime in the future by the given number of seconds. *)

val in_the_past : t -> bool
(** Whether the given datetime is in the past. *)
