open Nes
open Html

exception Non_convertible

type stacking_mode =
  | Default
  | No_label
  | Input_group
  | Horizontal

type ('value, 'state) t = Bundle of ('value, 'state) Component.s

let cons (type value1)(type state1)(type value2)(type state2)
    ?(stacking = Default)
    ((module C1): (value1, state1) Component.s)
    (Bundle(module C2): (value2, state2) t)
    : (value1 * value2, state1 * state2) t
  =
  Bundle (module struct
    let label = "Cons"

    type value = (value1 * value2)

    type state = C1.state * C2.state
    [@@deriving yojson]

    let empty =
      (C1.empty, C2.empty)

    let from_initial_text text =
      (C1.from_initial_text text, C2.empty)

    let value_to_string _ = lwt "<FIXME cons>"

    let value_to_state (v1, v2) =
      let%lwt v1 = C1.value_to_state v1 in
      let%lwt v2 = C2.value_to_state v2 in
      lwt (v1, v2)

    type t = {
      c1: C1.t;
      c2: C2.t;
    }

    let signal pair =
      RS.bind (C1.signal pair.c1) @@ fun v1 ->
      RS.bind (C2.signal pair.c2) @@ fun v2 ->
      RS.pure (v1, v2)

    let state pair =
      S.bind (C1.state pair.c1) @@ fun v1 ->
      S.bind (C2.state pair.c2) @@ fun v2 ->
      S.const (v1, v2)

    let focus pair = C1.focus pair.c1
    let trigger pair = C1.trigger pair.c1

    let set pair (v1, v2) =
      C1.set pair.c1 v1;%lwt
      C2.set pair.c2 v2

    let clear pair =
      C1.clear pair.c1;%lwt
      C2.clear pair.c2

    let inner_html pair =
      match stacking with
      | Default ->
        div [
          Component.html' (module C1) pair.c1;
          C2.inner_html pair.c2;
        ]
      | No_label ->
        div [
          div [C1.inner_html pair.c1] ~a: [a_class ["mb-1"]];
          div [C2.inner_html pair.c2];
        ]
      | Input_group ->
        div ~a: [a_class ["input-group"]] [
          span ~a: [a_class ["input-group-text"]] [txt C1.label];
          C1.inner_html pair.c1;
          span ~a: [a_class ["input-group-text"]] [txt C2.label];
          C2.inner_html pair.c2;
        ]
      | Horizontal ->
        div [
          C1.inner_html pair.c1;
          C2.inner_html pair.c2;
        ]

    let actions _ = S.const []

    let initialise (initial_value1, initial_value2) =
      let%lwt c1 = C1.initialise initial_value1 in
      let%lwt c2 = C2.initialise initial_value2 in
      lwt {c1; c2}
  end)

let (^::) = cons

let nil : (unit, unit) t = Bundle (Nil.prepare ())

(* FIXME: from a consumer's perspective, the [?stacking] argument should belong
   to [group], but that supposes we have a way to apply [cons] later, which does
   sound doable but isn't trivial right now *)

let group (type value)(type value_wrapped)(type state)
    ?label
    ~(wrap : value -> value_wrapped)
    ~(unwrap : value_wrapped -> value)
    ?(check : (value_wrapped -> value_wrapped -> bool) option)
    (Bundle(module C): (value, state) t)
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
    include C
    let label = the_label
    type value = value_wrapped
    let value_to_string w = C.value_to_string (unwrap w)
    let value_to_state w = C.value_to_state (unwrap w)
    let signal b = S.map (Result.map wrap) (C.signal b)
    let set b w = C.set b (unwrap w)
    let initialise initial_value = C.initialise initial_value
  end)

let pair ?label ?stacking ~wrap ~unwrap c1 c2 =
  group
    ?label
    ~wrap: (fun (v1, (v2, ())) -> wrap (v1, v2))
    ~unwrap: (fun x -> let (v1, v2) = unwrap x in (v1, (v2, ())))
    (cons ?stacking c1 (cons ?stacking c2 nil))

let triplet ?label ?stacking ~wrap ~unwrap c1 c2 c3 =
  group
    ?label
    ~wrap: (fun (v1, (v2, (v3, ()))) -> wrap (v1, v2, v3))
    ~unwrap: (fun x -> let (v1, v2, v3) = unwrap x in (v1, (v2, (v3, ()))))
    (cons ?stacking c1 (cons ?stacking c2 (cons ?stacking c3 nil)))

let quadruplet ?label ?stacking ~wrap ~unwrap c1 c2 c3 c4 =
  group
    ?label
    ~wrap: (fun (v1, (v2, (v3, (v4, ())))) -> wrap (v1, v2, v3, v4))
    ~unwrap: (fun x -> let (v1, v2, v3, v4) = unwrap x in (v1, (v2, (v3, (v4, ())))))
    (cons ?stacking c1 (cons ?stacking c2 (cons ?stacking c3 (cons ?stacking c4 nil))))
