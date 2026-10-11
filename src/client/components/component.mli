(** {1 Component} *)

open Html

(** {2 Regular interface} *)

type ('value, 'state) t
(** The type of an initialised component carrying ['value]s. At any point in
    time, it will have an internal ['state]. However, depending on that state,
    it might or not carry a ['value]. *)

val focus : ('value, 'state) t -> unit
val trigger : ('value, 'state) t -> unit
val clear : ('value, 'state) t -> unit Lwt.t

val signal : ('value, 'state) t -> ('value, string) result S.t
(** Expose the value held by the component. *)

val state : ('value, 'state) t -> 'state S.t
(** Expose the internal state of the component. This function should be avoided
    as much as possible. *)

val set : ('value, 'state) t -> 'value -> unit Lwt.t
(** Set the component to hold the specific value. *)

val inner_html : ('value, 'state) t -> Html_types.div_content_fun elt

val html : ('value, 'state) t -> [> Html_types.div] elt
(** Render the component as HTML. This is not provided by the component itself,
    but is rather a wrapper shared by all components around their
    {!inner_html}. *)

val html_fake : label: string -> Html_types.div_content_fun elt -> [> Html_types.div] elt
(** Mimmics a component in terms of spacing above and below and position of the
    label. *)

(** {2 Module and functor interface}

    This is the interface that composes well. As a creator of components, this
    is what you want to manipulate. As a consumer of a component, you do not
    need to go into this. *)

module type S = sig
  val label : string

  type state [@@deriving yojson]
  (** The type of internal states of the component. They can represent all that
      the component can. For instance, for an input, this would be a string. *)

  val empty : state
  (** The empty state of the component. *)

  val from_initial_text : string -> state

  type value

  val value_to_string : value -> string Lwt.t
  (** Return a string describing the content of the component. This is only
      meant to be used for visual feedback. *)

  val value_to_state : value -> state Lwt.t

  type t

  val initialise : state -> t Lwt.t

  val state : t -> state S.t
  val signal : t -> (value, string) result S.t

  val set : t -> value -> unit Lwt.t
  (** Set the value of the component. *)

  val clear : t -> unit Lwt.t
  (** Clear the component, bringing the state back to {!empty}. *)

  val focus : t -> unit
  (** Focus the component. For instance, for an input, the cursor will be put in
      the input. See also {!trigger}. *)

  val trigger : t -> unit
  (** Trigger the component. For simple components, this is akin to {!focus}.
      For components with a button triggering an action, though, {!focus} will
      only focus the button, while {!trigger} will trigger the action. *)

  val inner_html : t -> Html_types.div_content_fun elt
  val actions : t -> Html_types.div_content_fun elt list S.t
end

type ('value, 'state) s = (module S with type value = 'value and type state = 'state)
(** The type of an un-initialised component. This is the type that composes well
    and that one should provide to eg. {!ComponentList}. *)

val initialise :
  ('value, 'state) s ->
  'state ->
  ('value, 'state) t Lwt.t
(** Initialise a prepared component into a wrapped component of type {!t}.
    Depending on your use case, you might prefer calling {!S.initialise}
    directly and store the value of type {!S.t}. *)

(** {2 Utilities} *)

val html' :
  (module S with type t = 'a and type value = 'value and type state = 'state) ->
  'a ->
  [> Html_types.div] elt
(** Render the component as HTML, just like {!html} would. *)

val html'' :
  label: string ->
  actions: (Html_types.div_content_fun elt list S.t) ->
  signal: ('a, string) result Html.S.t ->
  inner_html: Html_types.div_content_fun elt ->
  [> Html_types.div] elt
(** Render the HTML, just like {!html} would. *)

val case_errored :
  no: 'b ->
  yes: ('e -> 'b) ->
  ('a, 'e) result S.t ->
  'b S.t
