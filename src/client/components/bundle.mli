(** {1 Bundle of components}

    An editor features several components, and therefore we provide here a way
    to bundle components together under a list-like structure. *)

type ('value, 'state) t =
  Bundle of ('value, 'state) Component.s

val nil : (unit, unit) t

val cons :
  ('value1, 'state1) Component.s ->
  ('value2, 'state2) t ->
  ('value1 * 'value2, 'state1 * 'state2) t

val (^::):
  ('value1, 'state1) Component.s ->
  ('value2, 'state2) t ->
  ('value1 * 'value2, 'state1 * 'state2) t
(** [c ^:: cs] is an alias for [cons c cs]. It is right associative. *)
