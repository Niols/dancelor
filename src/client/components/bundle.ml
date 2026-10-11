open Nes
open Html

(* Tuple elements *)

type _ tuple_element =
  | Zero : 'a -> ('a * 'b) tuple_element
  | Succ : 'b tuple_element -> ('a * 'b) tuple_element
(** An element = its index in a tuple of the form [(x, (y, (z, ...)))]. *)
(* TODO: Explore the idea of
   | Succ : ('b * 'c) elt -> ('a * ('b * 'c)) elt
   | Last : unit elt -> ('a * unit) elt
   or something like that to remove the assert false in client uses *)

let zero x = Zero x
let succ e = Succ e
let one x = Succ (Zero x)
let two x = Succ (Succ (Zero x))
let three x = Succ (Succ (Succ (Zero x)))

(** It is safe to consume a [unit t] because nothing can construct it.
    Morally, this can be thought of as [-1]. *)
let consume_negative_tuple_element : unit tuple_element -> 'a = fun _ ->
  assert false

(** The index of the tuple element in the tuple. *)
let rec tuple_element_index : type any. any tuple_element -> int = function
  | Zero _ -> 0
  | Succ b -> 1 + tuple_element_index b

(* Bundles of components *)

module type S = sig
  type value

  type state [@@deriving yojson]
  (** Typically, this will be a tuple of the form (_, (_, (_, ()))). *)

  val all_labels : string list

  val empty : state

  val from_initial_text_first : string -> state
  val from_initial_text_all : string -> state

  val value_to_state : value -> state Lwt.t

  val value_to_state_at : value tuple_element -> state Lwt.t
  (** Given one value among a tuple, create the state where everything is
      empty, except for that one value where we call the corresponding
      {!Component.S.value_to_state}. *)

  type t

  val initialise : state -> t Lwt.t

  val state : t -> state S.t

  val signal : t -> (value, string) result S.t

  val all_signals : t -> (unit, string) result S.t list

  val signal_at : t -> int -> (value tuple_element, string) result S.t
  (** Value of the component at the given index, or the error of that component.
      The value is returned as a {!tuple_element}. *)

  val all_actions : t -> Html_types.div_content_fun elt list S.t list
  (** The list of all actions of the components. *)

  val all_inner_htmls : t -> Html_types.div_content_fun elt list
  (** The list of all inner HTMLs of the components. *)

  val choices :
    ?offset: int ->
    ?initial_selected: int ->
    t ->
    int Choices.choice list
  (** One choice per component, starting from the given index. The [?offset]
      argument should only be used by the {!cons} function. *)

  val set : t -> value -> unit Lwt.t

  val set_at : t -> value tuple_element -> unit Lwt.t
  (** Given one value among a tuple, set the whole bundle to empty everywhere,
      except for that one value. *)

  val clear : t -> unit Lwt.t
  (** Clear all the components of the bundle. *)

  val focus_first : t -> unit
  val trigger_first : t -> unit
end

type ('value, 'state) t = (module S with type value = 'value and type state = 'state)

let cons (type value1)(type value2)(type state1)(type state2)
  ((module A): (value1, state1) Component.s)
  ((module B): (value2, state2) t)
  : (value1 * value2, state1 * state2) t
= (module struct
  type value = value1 * value2
  type state = A.state * B.state [@@deriving yojson]

  let all_labels = A.label :: B.all_labels

  let empty =
    (A.empty, B.empty)

  let from_initial_text_first text =
    (A.from_initial_text text, B.empty)

  let from_initial_text_all text =
    (A.from_initial_text text, B.from_initial_text_all text)

  let value_to_state (va, vb) =
    let%lwt va = A.value_to_state va in
    let%lwt vb = B.value_to_state vb in
    lwt (va, vb)

  let value_to_state_at = function
    | Zero v -> let%lwt a_state = A.value_to_state v in lwt (a_state, B.empty)
    | Succ elt -> let%lwt b_state = B.value_to_state_at elt in lwt (A.empty, b_state)

  type t = {a: A.t; b: B.t}

  let state t =
    S.bind (A.state t.a) @@ fun va ->
    S.bind (B.state t.b) @@ fun vb ->
    S.const (va, vb)

  let signal t =
    RS.bind (A.signal t.a) @@ fun va ->
    RS.bind (B.signal t.b) @@ fun vb ->
    RS.pure (va, vb)

  let all_signals t =
    S.map (Result.map (const ())) (A.signal t.a) :: B.all_signals t.b

  let signal_at t = function
    | 0 -> S.map (Result.map zero) (A.signal t.a)
    | n -> S.map (Result.map succ) (B.signal_at t.b (n - 1))

  let initialise (va, vb) =
    let%lwt a = A.initialise va in
    let%lwt b = B.initialise vb in
    lwt {a; b}

  let all_actions t =
    A.actions t.a :: B.all_actions t.b

  let all_inner_htmls t =
    A.inner_html t.a :: B.all_inner_htmls t.b

  let choices ?(offset = 0) ?initial_selected t =
    Choices.choice
      ~value: offset
      ~checked: (initial_selected = Some offset)
      [txt A.label]
      ~onclick: (fun () ->
        (* Calling [A.trigger t.a] directly ends up with the focus in the
           wrong place; [Lwt.async] + [Lwt.pause] to the rescue. *)
        Lwt.async @@ fun () ->
        Lwt.pause ();%lwt
        A.trigger t.a;
        lwt_unit
      ) :: B.choices ~offset: (offset + 1) ?initial_selected t.b

  let set t (va, vb) =
    A.set t.a va;%lwt
    B.set t.b vb

  let set_at t = function
    | Zero v -> A.set t.a v;%lwt B.clear t.b
    | Succ elt -> A.clear t.a;%lwt B.set_at t.b elt

  let clear t =
    A.clear t.a;%lwt
    B.clear t.b

  let focus_first t = A.focus t.a
  let trigger_first t = A.trigger t.a
end)

let (^::) = cons

let nil : (unit, unit) t = (module struct
  type value = unit
  type state = unit [@@deriving yojson]
  let all_labels = []
  let empty = ()
  let from_initial_text_all _ = ()
  let from_initial_text_first _ = ()
  let value_to_state () = lwt_unit
  let value_to_state_at = consume_negative_tuple_element
  type t = unit
  let state _ = S.const ()
  let signal _ = S.const (Ok ())
  let all_signals _ = []
  let signal_at _ _ = invalid_arg "Components.Bundle.nil.signal_at"
  let initialise () = lwt_unit
  let all_actions _ = []
  let all_inner_htmls _ = []
  let choices ?offset: _ ?initial_selected: _ () = []
  let set _ _ = lwt_unit
  let set_at _ _ = lwt_unit
  let clear _ = lwt_unit
  let focus_first _ = ()
  let trigger_first _ = ()
end)

(* Grouping a bundle into a component *)

exception Non_convertible

type stacking_mode =
  | Default
  | No_label
  | Input_group
  | Horizontal

let group (type value)(type value_wrapped)(type state)
    ?label
    ?(stacking = Default)
    ~(wrap : value -> value_wrapped)
    ~(unwrap : value_wrapped -> value)
    ?(check : (value_wrapped -> value_wrapped -> bool) option)
    ((module B): (value, state) t)
    : (value_wrapped, state) Component.s
  =
  (* pimped version of [unwrap] that checks the roundtrip *)
  let unwrap =
    match check with
    | None -> unwrap
    | Some check ->
      (fun w ->
        let v = unwrap w in
        let w' = wrap v in
        if not (check w w') then
          raise Non_convertible;
        v
      )
  in
  let the_label = Option.value label ~default: "<placeholder group label>" in
  (module struct
    let label = the_label
    type value = value_wrapped
    type state = B.state [@@deriving yojson]
    type t = B.t
    let value_to_string _ = lwt "<Bundle.group>"
    let value_to_state w = B.value_to_state (unwrap w)
    let signal b = S.map (Result.map wrap) (B.signal b)
    let set b w = B.set b (unwrap w)
    let initialise initial_value = B.initialise initial_value
    let empty = B.empty
    let focus = B.focus_first
    let trigger = B.trigger_first
    let from_initial_text = B.from_initial_text_first
    let actions _ = S.const []
    let state = B.state
    let clear = B.clear

    let inner_html t =
      match stacking with
      | Default ->
        div @@
          List.map
            (fun ((label, signal), (actions, inner_html)) ->
              Component.html'' ~label ~actions ~signal ~inner_html
            )
            (
              List.combine
                (
                  List.combine
                    B.all_labels
                    (B.all_signals t)
                )
                (
                  List.combine
                    (B.all_actions t)
                    (B.all_inner_htmls t)
                )
            )
      | No_label ->
        div @@
          List.map
            (fun inner_html ->
              (* FIXME: no margin under the last one? *)
              div ~a: [a_class ["mb-1"]] [inner_html]
            )
            (B.all_inner_htmls t)
      | Input_group ->
        div ~a: [a_class ["input-group"]] (
          List.concat_map
            (fun (label, inner_html) ->
              [
                span ~a: [a_class ["input-group-text"]] [txt label];
                inner_html;
              ]
            )
            (List.combine B.all_labels (B.all_inner_htmls t))
        )
      | Horizontal ->
        div (B.all_inner_htmls t)
  end)

let pair ?label ?stacking ~wrap ~unwrap c1 c2 =
  group
    ?label
    ?stacking
    ~wrap: (fun (v1, (v2, ())) -> wrap (v1, v2))
    ~unwrap: (fun x -> let (v1, v2) = unwrap x in (v1, (v2, ())))
    (cons c1 (cons c2 nil))

let triplet ?label ?stacking ~wrap ~unwrap c1 c2 c3 =
  group
    ?label
    ?stacking
    ~wrap: (fun (v1, (v2, (v3, ()))) -> wrap (v1, v2, v3))
    ~unwrap: (fun x -> let (v1, v2, v3) = unwrap x in (v1, (v2, (v3, ()))))
    (cons c1 (cons c2 (cons c3 nil)))

let quadruplet ?label ?stacking ~wrap ~unwrap c1 c2 c3 c4 =
  group
    ?label
    ?stacking
    ~wrap: (fun (v1, (v2, (v3, (v4, ())))) -> wrap (v1, v2, v3, v4))
    ~unwrap: (fun x -> let (v1, v2, v3, v4) = unwrap x in (v1, (v2, (v3, (v4, ())))))
    (cons c1 (cons c2 (cons c3 (cons c4 nil))))

(* Summing a bundle into a component *)

let plus (type value)(type bundled_value)(type state)
  ~label
  ~(cast : bundled_value tuple_element -> value)
  ~(uncast : value -> bundled_value tuple_element)
  ?(selected_when_empty : int option)
  (bundle : (bundled_value, state) t)
  : (value, int option * state) Component.s
= (module struct
  module Bundle = (val bundle)

  let label = label

  type nonrec value = value
  type state = int option * Bundle.state [@@deriving yojson]

  let value_to_string _value = lwt "<FIXME plus>"

  let value_to_state value =
    let elt = uncast value in
    let selected = Some (tuple_element_index elt) in
    let%lwt bundle_state = Bundle.value_to_state_at elt in
    lwt (selected, bundle_state)

  let empty = (selected_when_empty, Bundle.empty)
  let from_initial_text text = (selected_when_empty, Bundle.from_initial_text_all text)

  type t = {
    choices: (int, bool list) Component.t;
    bundle: Bundle.t;
  }

  let selected t = S.map Result.to_option (Component.signal t.choices)

  let state t =
    S.bind (selected t) @@ fun selected ->
    S.bind (Bundle.state t.bundle) @@ fun bundle_state ->
    S.const (selected, bundle_state)

  let signal t =
    S.bind (selected t) @@ function
      | None -> S.const (Error ("You must select a " ^ String.lowercase_ascii label ^ "."))
      | Some selected -> S.map (Result.map cast) (Bundle.signal_at t.bundle selected)

  let initialise (initial_selected, initial_states) =
    let%lwt bundle = Bundle.initialise initial_states in
    let%lwt choices = Choices.make_radios ~label (Bundle.choices ?initial_selected bundle) in
    lwt {choices; bundle}

  let inner_html p =
    div [
      div ~a: [a_class ["row"]] [
        div ~a: [a_class ["col"]] [Component.inner_html p.choices];
        R.div ~a: [a_class ["col-auto"]] (
          S.bind (Component.signal p.choices) @@ function
            | Error _ -> S.const []
            | Ok n -> List.nth (Bundle.all_actions p.bundle) n
        );
      ];
      R.div ~a: [a_class ["ps-2"; "mt-1"; "border-start"]] (
        S.flip_map (Component.signal p.choices) @@ function
          | Error _ -> []
          | Ok n -> [List.nth (Bundle.all_inner_htmls p.bundle) n]
      );
    ]

  let actions _ = S.const []

  let focus t = Component.focus t.choices
  let trigger t = Component.trigger t.choices

  let set t v =
    let v = uncast v in
    Component.set t.choices (tuple_element_index v);%lwt
    Bundle.set_at t.bundle v

  let clear t =
    Component.clear t.choices;%lwt
    Bundle.clear t.bundle
end)
