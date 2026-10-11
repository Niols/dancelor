(** {1 Bundle of components}

    An editor features several components, and therefore we provide here a way
    to bundle components together under a list-like structure. *)

(** {2 Bundle of components} *)

type ('value, 'state) t

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

(** {2 Grouping a bundle into a component} *)

type stacking_mode =
  | Default
  | No_label
  | Input_group
  | Horizontal

val group :
  ?label: string ->
  ?stacking: stacking_mode ->
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

(** {2 Summing a bundle into a component} *)

type _ tuple_element =
  | Zero : 'a -> ('a * 'w) tuple_element
  | Succ : 'w tuple_element -> ('a * 'w) tuple_element
(** Index in a tuple of the form [(x, (y, (z, ...)))]. *)

val zero : 'a -> ('a * 'w) tuple_element
val succ : 'w tuple_element -> ('a * 'w) tuple_element

val one : 'b -> ('a * ('b * 'w)) tuple_element
val two : 'c -> ('a * ('b * ('c * 'w))) tuple_element
val three : 'd -> ('a * ('b * ('c * ('d * 'w)))) tuple_element

val plus :
  label: string ->
  cast: ('bundled_value tuple_element -> 'value) ->
  uncast: ('value -> 'bundled_value tuple_element) ->
  ?selected_when_empty: int ->
  ('bundled_value, 'state) t ->
  ('value, int option * 'state) Component.s
(** Prepare a sum of components. The components have to be bundled together. The
    user must provide [cast] and [uncast] functions to go from a {!tuple_element} to
    whatever value they care about and vice-versa. In the simplest sum of two
    elements, using {!Either.t} as ['value], these functions could be:

    {[
      let cast = function
        | Zero x -> Left x
        | Succ Zero x -> Right x
        | _ -> assert false (* not reachable *)

      let uncast = function
        | Left x -> zero x
        | Right x -> one x
    ]}
  *)
