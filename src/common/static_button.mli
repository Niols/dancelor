open Tyxml.Html

val make :
  ?label: string ->
  ?icon: Icon.t ->
  ?badge: string ->
  ?tooltip: string ->
  ?dropdown: bool ->
  ?classes: string list ->
  ?more_a: [< Html_types.button_attrib >`Button_Type `Class `Title] attrib list ->
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
  ?icon: Icon.t ->
  ?badge: string ->
  ?tooltip: string ->
  ?dropdown: bool ->
  ?classes: string list ->
  href: Uri.t ->
  ?more_a: [< Html_types.a_attrib >`Class `Href `Title] attrib list ->
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
