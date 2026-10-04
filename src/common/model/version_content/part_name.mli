open Nes

type t
[@@deriving eq, ord, show]
(** An abstract part name, eg. “A”, “B”, “C”, etc., for use in a structure. *)

val to_int : t -> int
(** A part name, as an integer, starting from 0 = “A”. *)

val to_char : t -> char
(** A part name, as a single character, eg. ['A'] or ['H']. *)

val to_string : t -> string

val of_int : int -> t
val of_char : char -> t option
val of_char_exn : char -> t
(** Same as {!of_char} but raises [Failure]. *)

val of_string : string -> t option
(** Check that the string is a single character that is a part name. *)

type open_ =
  Start | Middle of t | End
[@@deriving eq, ord, yojson, show, variants]
(** A part, or possibly the start or the end of a tune. This is useful to
    manipulate transitions into or out of the tune. *)

val open_of_string : string -> open_ option
(** Either ["start"] or ["end"] or a {!to_char}. *)

val open_to_string : open_ -> string

type opens = open_ NEList.t
[@@deriving eq, ord, yojson, show]

val opens_of_string : string -> opens option
(** Comma-separated list of open part names. *)

val opens_to_string : opens -> string
