open Nes

type t = Part_name.t NEList.t
[@@deriving eq, ord, show, yojson]

val to_string : t -> NEString.t
val of_string : NEString.t -> t option

type folded_item = Part of Part_name.t | Repeat of int * folded
and folded = folded_item list

val part : Part_name.t -> folded_item
val repeat : int -> folded -> folded_item

val first_part : folded -> Part_name.t option
(** Find the first part in a structure, regarless of whether it appears in a
    repeat. *)

val first_part_exn : folded -> Part_name.t
(** Like {!first_part} but raises [Failure] if there is no first part. *)

val last_part : folded -> Part_name.t option
(** Find the last part in a structure, regarless of whether it appears in a
    repeat. *)

val last_part_exn : folded -> Part_name.t
(** Like {!last_part} but raises [Failure] if there is no last part. *)

val best_fold_for : t -> folded option
(** Given a (normal, flat) structure, compute the best possible fold for it,
    or return [None] if there is no good one. *)
