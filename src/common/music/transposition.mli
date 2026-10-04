type t
[@@deriving eq, ord, show, yojson]

val identity : t

(** Make a transposition from a (potentially negative) number of semitones. *)
val from_semitones : int -> t

(** Make a transposition from a (potentially negative) number of octaves. *)
val from_octaves : int -> t

val target_pitch : source: Pitch.t -> t -> Pitch.t

val to_semitones : t -> int

val compose : t -> t -> t
