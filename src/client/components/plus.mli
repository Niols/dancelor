(** {1 Sum of components} *)

(** {2 Tuple elements} *)

module Tuple_elt : sig
  type _ t =
    | Zero : 'a -> ('a * 'b) t
    | Succ : 'b t -> ('a * 'b) t
  (** A type for elements of a tuple. For the use case of this component, it is
      not necessary for this type to be as general as it could.

      For instance, if we consider the tuple [(1, (2., ("3", ())))], of type [int
      * (float * (string * unit))], its elements would be [Zero 1], [Succ (Zero
      2.)], and [Succ (Succ (Zero "3"))], all of type [(int * (float * (string *
      unit))) t]. *)

  val one : 'b -> ('a * ('b * 'c)) t
  (** [one x] is short for [Succ (Zero x)]. *)

  val two : 'c -> ('a * ('b * ('c * 'd))) t
  (** [two x] is short for [Succ (Succ (Zero x))]. *)

  val three : 'd -> ('a * ('b * ('c * ('d * 'e)))) t
  (** [three x] is short for [Succ (Succ (Succ (Zero x)))]. *)
end

(** {2 Bundles of components} *)

module Bundle : sig
  type ('value, 'state) t
  (** A bundle of components. This can be thought of as a list of components,
      except that the types are heterogeneous. *)

  val cons :
    ('value1, 'state1) Component.s ->
    ('value2, 'state2) t ->
    ('value1 * 'value2, 'state1 * 'state2) t
  (** Add a component at the front of a bundle of components. *)

  val (^::):
    ('value1, 'state1) Component.s ->
    ('value2, 'state2) t ->
    ('value1 * 'value2, 'state1 * 'state2) t
  (** Alias for {!cons}. *)

  val nil : (unit, unit) t
  (** The empty bundle of components. *)
end

(** {2 Sum of components} *)

val prepare :
  label: string ->
  cast: ('bundled_value Tuple_elt.t -> 'value) ->
  uncast: ('value -> 'bundled_value Tuple_elt.t) ->
  ?selected_when_empty: int ->
  ('bundled_value, 'state) Bundle.t ->
  ('value, int option * 'state) Component.s
(** Prepare a sum of components. The components have to be bundled together. The
    user must provide [cast] and [uncast] functions to go from a {!tuple_elt} to
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
