(** {1 Base Kind} *)

type t =
  | Air
  | Hornpipe
  | Jig
  | Jig_9_8
  | March_2_4
  | March_4_4
  | March_6_8
  | Other
  | Polka
  | Reel
  | Schottische
  | Strathspey
  | Two_step
  | Waltz
[@@deriving eq, ord, show, yojson]

val all : t list

val to_short_string : t -> string
(** Short string, eg. ["S"]. *)

val to_long_string : capitalised: bool -> t -> string
(** Long string, eg. ["Strathspey"]. If [~capitalised], then the first letter is
    capitalised. *)

val of_string : string -> t
val of_string_opt : string -> t option

val tempo : t -> string * int
(** Returns the base lilypond unit and the associated tempo. eg. [("2", 108)]
    for reels. *)
