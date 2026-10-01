(** {1 Bundle of components}

    An editor features several components, and therefore we provide here a way
    to bundle components together under a list-like structure. *)

type ('value, 'state) t =
  Bundle of ('value, 'state) Component.s

(* FIXME: move to mode if possible *)
type stacking_mode =
  | Default
  | No_label
  | Input_group
  | Horizontal

val nil : (unit, unit) t

val cons :
  ?stacking: stacking_mode ->
  ('value1, 'state1) Component.s ->
  ('value2, 'state2) t ->
  ('value1 * 'value2, 'state1 * 'state2) t

val (^::):
  ?stacking: stacking_mode ->
  ('value1, 'state1) Component.s ->
  ('value2, 'state2) t ->
  ('value1 * 'value2, 'state1 * 'state2) t
(** [c ^:: cs] is an alias for [cons c cs]. It is right associative. *)

val group :
  ?label: string ->
  wrap: ('value -> 'wrapped) ->
  unwrap: ('wrapped -> 'value) ->
  ?check: ('wrapped -> 'wrapped -> bool) ->
  ('value, 'state) t ->
  ('wrapped, 'state) Component.s

val pair :
  ?label: string ->
  ?stacking: stacking_mode ->
  wrap: ('value1 * 'value2 -> 'wrapped) ->
  unwrap: ('wrapped -> 'value1 * 'value2) ->
  ('value1, 'state1) Component.s ->
  ('value2, 'state2) Component.s ->
  ('wrapped, 'state1 * ('state2 * unit)) Component.s
(** Shortcut for a group of two components. *)

val triplet :
  ?label: string ->
  ?stacking: stacking_mode ->
  wrap: ('value1 * 'value2 * 'value3 -> 'wrapped) ->
  unwrap: ('wrapped -> 'value1 * 'value2 * 'value3) ->
  ('value1, 'state1) Component.s ->
  ('value2, 'state2) Component.s ->
  ('value3, 'state3) Component.s ->
  ('wrapped, 'state1 * ('state2 * ('state3 * unit))) Component.s
(** Shortcut for a group of three components. *)

val quadruplet :
  ?label: string ->
  ?stacking: stacking_mode ->
  wrap: ('value1 * 'value2 * 'value3 * 'value4 -> 'wrapped) ->
  unwrap: ('wrapped -> 'value1 * 'value2 * 'value3 * 'value4) ->
  ('value1, 'state1) Component.s ->
  ('value2, 'state2) Component.s ->
  ('value3, 'state3) Component.s ->
  ('value4, 'state4) Component.s ->
  ('wrapped, 'state1 * ('state2 * ('state3 * ('state4 * unit)))) Component.s
(** Shortcut for a group of four components. *)
