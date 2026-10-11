(** {1 Input components} *)

open Nes
open React
open Js_of_ocaml_tyxml.Tyxml_js

type type_ = Text | Password | Textarea of {rows: int}
type font = Normal | Monospace

val make :
  type_: type_ ->
  ?font: font ->
  label: string ->
  ?placeholder: string ->
  serialise: ('value -> string) ->
  validate: (string -> ('value, string) result S.t) ->
  ?oninput: (string -> unit) ->
  ?template: string ->
  string ->
  ('value, string) Component.t Lwt.t

val make_option :
  type_: type_ ->
  ?font: font ->
  label: string ->
  ?placeholder: string ->
  serialise: ('value -> NEString.t) ->
  validate: (NEString.t -> ('value, string) result S.t) ->
  ?oninput: (string -> unit) ->
  ?template: string ->
  string ->
  ('value option, string) Component.t Lwt.t

val make_non_empty :
  type_: type_ ->
  ?font: font ->
  label: string ->
  ?placeholder: string ->
  ?oninput: (string -> unit) ->
  ?template: string ->
  string ->
  (NEString.t, string) Component.t Lwt.t

val inactive :
  label: string ->
  string ->
  [> Html_types.div] Html.elt
(** An inactive text input, compatible graphically with [make ~type_: Text]. *)

(** {2 Internal use} *)

val prepare :
  type_: type_ ->
  ?font: font ->
  label: string ->
  ?placeholder: string ->
  serialise: ('value -> string) ->
  validate: (string -> ('value, string) result S.t) ->
  ?oninput: (string -> unit) ->
  ?template: string ->
  unit ->
  ('value, string) Component.s
(** Variant of {!make} that only prepares the component. It must still be
    {!Component.initialise}d. This is used for composition with eg.
    {!ComponentList}. *)

val prepare_option :
  type_: type_ ->
  ?font: font ->
  label: string ->
  ?placeholder: string ->
  serialise: ('value -> NEString.t) ->
  validate: (NEString.t -> ('value, string) result S.t) ->
  ?oninput: (string -> unit) ->
  ?template: string ->
  unit ->
  ('value option, string) Component.s

val prepare_non_empty :
  type_: type_ ->
  ?font: font ->
  label: string ->
  ?placeholder: string ->
  ?oninput: (string -> unit) ->
  ?template: string ->
  unit ->
  (NEString.t, string) Component.s
