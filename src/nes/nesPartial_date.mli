(** {1 Partial Date}

    This module implements the notion of partial date, that is a date from which
    the day or the month may be missing. *)

type t [@@deriving eq, show, yojson]
(** The type of a partial date. *)

val from_string : string -> t option
(** Parses the date from a potentially-truncated ISO 8601 string, eg.
    [2022-11-09], [2022-11] or [2022]. *)

val to_string : t -> string
(** Prints the date as a potentially-truncated ISO 8601 string, eg.
    [2022-11-09], [2022-11] or [2022], *)

val to_pretty_string : ?at: bool -> ?short: bool -> t -> string
(** Prints the date as a pretty string, eg. [9 November 2022], [November 2022]
    or [2022]. The [?at] argument allows to represent the string “at <date>”,
    eg. [on 9 November 2022], [in November 2022] or [in 2022]. The [?short]
    argument makes the month name short, eg. [9 Nov 2022]. *)

val compare : t -> t -> int
(** Compares two strings. *)
