open Nes

type destructured = {
  parts: Voices.t NEList.t;
  transitions: (Part_name.opens * Part_name.opens * Voices.t) list;
  default_structure: Structure.t;
  as_2_4: bool; (** only used for binary kinds *)
}

type t =
  | No_content (** A tune without content - metadata only *)
  | Destructured of destructured (** A tune decomposed as building blocks *)
  | Monolithic of {lilypond: string; bars: int; structure: Structure.t} (** A tune as a full LilyPond, including clef, key, etc. *)
[@@deriving eq, ord, yojson, show, variants]

val lilypond : ?structure: Structure.t -> kind: Kind.Base.t -> key: Music.Key.t -> t -> string option
(** Produce a LilyPond string from a content and some additional information.
    The [?structure] optional argument is ignored in case of monolithic content,
    but tries to produce a LilyPond for the given structure if possible. *)

val erase_lilypond : t -> t
(** Erase the LilyPond from a version content. This is used to send smaller
    payloads to the Dancelor client. *)
