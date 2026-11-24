(** {1 Datetime} *)

(** {2 Datetime} *)

type t [@@deriving eq, ord, yojson]

val to_timestamp : t -> float
val of_timestamp : float -> t
(** Number of seconds since 1 Jan 1970. *)

val of_string : string -> t option
val of_string_exn : string -> t
(** Parses an ISO 8601 datetime string. *)

val to_string : t -> string
(** Prints the date and time as an ISO 8601 string. *)

val pp : Format.formatter -> t -> unit
(** See {!to_string}. *)

val now : unit -> t
(** Returns the current date and time. *)

(** {2 Duration} *)

type duration [@@deriving eq, ord, yojson]

val forever : duration

val duration_to_seconds : duration -> float

val duration_of_seconds : float -> duration
val duration_of_seconds' : int -> duration
val duration_of_minutes : float -> duration
val duration_of_minutes' : int -> duration
val duration_of_hours : float -> duration
val duration_of_hours' : int -> duration
val duration_of_days : float -> duration
val duration_of_days' : int -> duration

val duration_to_string : duration -> string
(** ISO 8601-inspired format [P<d>DT<h>H<m>M<s>S] where [<s>] is a floating
    point number and years and months do not appear, because their semantics is
    imprecise outside a time interval. *)

val duration_of_string : string -> duration option
val duration_of_string_exn : string -> duration

val pp_duration_pretty : Format.formatter -> duration -> unit
val duration_to_string_pretty : duration -> string

val mult : duration -> float -> duration

(** {2 Both} *)

val diff : t -> t -> duration
(** Number of seconds between two datetimes. *)

val duration_to_now : t -> duration
(** Number of seconds from the given datetime to now. This is positive if the
    datetime is in the past. *)

val make_in_the_past : duration -> t
(** Make a datetime in the past by the given duration. *)

val make_in_the_future : duration -> t
(** Make a datetime in the future by the given duration. *)

val in_the_past : t -> bool
(** Whether the given datetime is in the past. *)
