(** {1 Partial Date}

    This module implements the notion of partial date, that is a date from which
    the day or the month may be missing. *)

type t [@@deriving eq, show, yojson]
(** The type of a partial date. *)

val make :
  year: int ->
  ?month0: int ->
  ?month1: int ->
  ?day0: int ->
  ?day1: int ->
  unit ->
  t
(** Makes a partial date from the given component. Months and days can be
    provided indexed from 0 or from 1, for convenience, but both cannot be
    provided. Day cannot be provided without a month. I will raise
    {!Invalid_argument} in those situations. *)

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

val of_unix_tm : Unix.tm -> t
(** Convert a {!Unix.tm} value into a partial date with year, month and day set. *)

val of_timestamp : float -> t
(** Convert a number of seconds from 1 Jan 1970, given as a float, to a partial
    date with year, month and day set. *)

val strip_day : t -> t
(** Removes the day from a partial date. *)

val strip_month : t -> t
(** Removes the month and the day from a partial date. *)

val year : t -> int
(** Returns the year of the partial date. *)

val month0 : t -> int option
(** Returns the month of the partial date, indexed from 0, if there is one. *)

val month1 : t -> int option
(** Returns the month of the partial date, indexed from 1, if there is one. *)

val day0 : t -> int option
(** Returns the day of the partial date, indexed from 0, if there is one. *)

val day1 : t -> int option
(** Returns the day of the partial date, indexed from 1, if there is one. *)
