open Dancelor_common
open Html

val make :
  ?label: string ->
  ?label_processing: string ->
  ?icon: Icon.t ->
  ?badge: string ->
  ?tooltip: string ->
  ?dropdown: bool ->
  ?classes: string list ->
  ?disabled: bool S.t ->
  ?onclick: (unit -> unit Lwt.t) ->
  ?more_a: [< Html_types.button_attrib >`Button_Type `Class `OnClick `Title] attrib list ->
  unit ->
  [> Html_types.button] elt
(** Generic button showing [label] and [icon]. When clicked, [label] is replaced
    by [label_processing], and [icon] by a spinning one. The button already has
    classes ["btn"] (unless [~dropdown: true]) and ["disabled"] when needed,
    but others can be added. When clicked, the button triggers [onclick] and
    considers its job done when [onclick] returns. It is possible to use
    [Lwt.async], but it is recommended to actually return when that makes
    sense. *)

val make_a :
  ?label: string ->
  ?label_processing: string ->
  ?icon: Icon.t ->
  ?badge: string ->
  ?tooltip: string ->
  ?disabled: bool S.t ->
  ?dropdown: bool ->
  ?classes: string list ->
  href: Uri.t S.t ->
  ?onclick: (unit -> unit Lwt.t) ->
  ?more_a: [< Html_types.a_attrib >`Class `Href `OnClick `Title] attrib list ->
  unit ->
  [> Html_types.a_] elt
(** Variant of {!make} that creates an anchor element [<a/>] instead
    of a [<button/>]. This makes sense when it is to be used as a link
    and not to trigger an action. The [?onclick] optional argument
    overrides the action of the link with that of the click. *)

val make_icon :
  ?classes: string list ->
  Icon.t ->
  [> Html_types.button] elt
(** Make a fake button showing an icon. Sometimes useful in button groups. *)

val save :
  ?label: string ->
  ?label_processing: string ->
  ?disabled: bool S.t ->
  onclick: (unit -> unit Lwt.t) ->
  unit ->
  [> Html_types.button] elt
(** A button specialised in saving a form. The label is “save” unless
    overridden. *)

val clear :
  onclick: (unit -> unit Lwt.t) ->
  unit ->
  [> Html_types.button] elt
(** A button specialised in clearing a form. *)

val cancel :
  ?onclick: (unit -> unit Lwt.t) ->
  ?more_a: [< Html_types.button_attrib >`Button_Type `Class `OnClick `Title] attrib list ->
  unit ->
  [> Html_types.button] elt
(** A button specialised in cancelling something. *)

val cancel' :
  return: ('any option -> unit) ->
  ?more_a: [< Html_types.button_attrib >`Button_Type `Class `OnClick `Title] attrib list ->
  unit ->
  [> Html_types.button] elt
(** Variant of {!cancel'} passing [None] to a [return] function. *)

val close :
  ?onclick: (unit -> unit Lwt.t) ->
  ?more_a: [< Html_types.button_attrib >`Button_Type `Class `OnClick `Title] attrib list ->
  unit ->
  [> Html_types.button] elt
(** A button specialised in closing something. *)

val close' :
  return: ('any option -> unit) ->
  ?more_a: [< Html_types.button_attrib >`Button_Type `Class `OnClick `Title] attrib list ->
  unit ->
  [> Html_types.button] elt
(** Variant of {!close'} passing [None] to a [return] function. *)

val ok' :
  return: (unit option -> unit) ->
  ?more_a: [< Html_types.button_attrib >`Button_Type `Class `OnClick `Title] attrib list ->
  unit ->
  [> Html_types.button] elt
(** Variant of {!ok'} passing [Some ()] to a [return] function. *)

val download :
  onclick: (unit -> unit Lwt.t) ->
  unit ->
  [> Html_types.button] elt
