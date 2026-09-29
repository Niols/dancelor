open Nes
open Html

type ('value, 'state) t = Bundle of ('value, 'state) Component.s

let cons (type value1)(type state1)(type value2)(type state2)
    (component : (value1, state1) Component.s)
    (Bundle bundle: (value2, state2) t)
    : (value1 * value2, state1 * state2) t
  =
  Bundle (module struct
    include (val Cpair.bundle ~wrap: id ~unwrap: id component bundle)

    let inner_html p =
      div [
        Component.html' (module C1) (c1 p);
        C2.inner_html (c2 p);
      ]
  end)

let (^::) = cons

let nil : (unit, unit) t = Bundle (Nil.prepare ())
