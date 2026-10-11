open Nes
open Html
open Utils

module type S = sig
  val label : string
  type state [@@deriving yojson]
  val empty : state
  val from_initial_text : string -> state
  type value
  val value_to_string : value -> string Lwt.t
  val value_to_state : value -> state Lwt.t
  type t
  val initialise : state -> t Lwt.t
  val state : t -> state S.t
  val signal : t -> (value, string) result S.t
  val set : t -> value -> unit Lwt.t
  val clear : t -> unit Lwt.t
  val focus : t -> unit
  val trigger : t -> unit
  val inner_html : t -> Html_types.div_content_fun elt
  val actions : t -> Html_types.div_content_fun elt list S.t
end

type ('value, 'state) s = (module S with type value = 'value and type state = 'state)

type ('value, 'state) t =
  Component :
      (module S with type t = 'a and type value = 'value and type state = 'state)
    * 'a ->
      ('value, 'state) t

let initialise (type value)(type state)
    (module C : S with type value = value and type state = state)
    (initial_value : state)
    : (value, state) t Lwt.t
  =
  let%lwt component = C.initialise initial_value in
  lwt @@ Component ((module C), component)

let focus : type value state. (value, state) t -> unit = function Component ((module C), c) -> C.focus c
let trigger : type value state. (value, state) t -> unit = function Component ((module C), c) -> C.trigger c
let clear : type value state. (value, state) t -> unit Lwt.t = function Component ((module C), c) -> C.clear c
let signal : type value state. (value, state) t -> (value, string) result S.t = function Component ((module C), c) -> C.signal c
let state : type value state. (value, state) t -> state S.t = function Component ((module C), c) -> C.state c
let set : type value state. (value, state) t -> value -> unit Lwt.t = function Component ((module C), c) -> C.set c
let inner_html : type value state. (value, state) t -> Html_types.div_content_fun elt = function Component ((module C), c) -> C.inner_html c

let case_errored ~no ~yes signal =
  S.flip_map signal @@ function
    | Error msg -> yes msg
    | _ -> no

let html'' ~label: the_label ~actions ~signal ~inner_html =
  div
    ~a: [a_class ["mb-2"]]
    [
      div ~a: [a_class ["row"; "align-items-center"]] [
        label ~a: [a_class ["col"]] [txt the_label];
        R.div ~a: [a_class ["col-auto"]] (
          S.flip_map actions @@ function
            | [] -> [Button.make ~classes: ["invisible"] ~icon: (Action Add) ()] (* for spacing *)
            | actions -> actions
        );
      ];
      inner_html;
      R.div
        ~a: [R.a_class (case_errored ~no: ["d-block"; "valid-feedback"] ~yes: (const ["d-block"; "invalid-feedback"]) signal)]
        (case_errored ~no: [txt " "] ~yes: (List.singleton % txt) signal);
    ]

let html'
  : type a value state. (module S with type t = a and type value = value and type state = state) ->
  a ->
  [> Html_types.div] elt
= fun (module C) c ->
  html''
    ~label: C.label
    ~actions: (C.actions c)
    ~signal: (C.signal c)
    ~inner_html: (C.inner_html c)

let html : type value state. (value, state) t -> [> Html_types.div] elt = function
  | Component ((module C), c) -> html' (module C) c

let html_fake ~label: label_ content =
  div
    ~a: [a_class ["mb-2"]]
    [
      label ~a: [a_class ["form-label"]] [txt label_];
      content;
      div ~a: [a_class ["d-block"; "valid-feedback"]] [txt " "];
    ]
