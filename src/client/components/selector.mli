(** {1 Selector component} *)

open Nes
open Dancelor_common
open Html

val make :
  label: string ->
  search: (Slice.t -> string -> ('model Search_result.t, string) Result.t Lwt.t) ->
  id_to_yojson: ('id -> Yojson.Safe.t) ->
  id_of_yojson: (Yojson.Safe.t -> ('id, string) result) ->
  serialise: ('model -> 'id) ->
  unserialise: ('id -> 'model option Lwt.t) ->
  make_descr: ('model -> string Lwt.t) ->
  make_result:
  (?classes: string list ->
  ?onclick: (unit -> unit Lwt.t) ->
  ?prefix: Html_types.td Html.elt list ->
  ?suffix: Html_types.td Html.elt list ->
  'model ->
  Html_types.tr Html.elt) ->
  ?make_more_results:
  ('model ->
  Html_types.tr Html.elt list S.t) ->
  ?results_when_no_search: 'model list Lwt.t ->
  model_name: string ->
  ?create_dialog_content: (('model, 'any) Editor.mode -> Page.t Lwt.t) ->
  'id option ->
  ('model, 'id option) Component.t Lwt.t
(** When [?create_dialog_content] is passed, an additional button allows to
    create a value of this type on the fly. *)

(** {2 Internal use} *)

val prepare :
  label: string ->
  search: (Slice.t -> string -> ('model Search_result.t, string) Result.t Lwt.t) ->
  id_to_yojson: ('id -> Yojson.Safe.t) ->
  id_of_yojson: (Yojson.Safe.t -> ('id, string) result) ->
  serialise: ('model -> 'id) ->
  unserialise: ('id -> 'model option Lwt.t) ->
  make_descr: ('model -> string Lwt.t) ->
  make_result:
  (?classes: string list ->
  ?onclick: (unit -> unit Lwt.t) ->
  ?prefix: Html_types.td Html.elt list ->
  ?suffix: Html_types.td Html.elt list ->
  'model ->
  Html_types.tr Html.elt) ->
  ?make_more_results:
  ('model ->
  Html_types.tr Html.elt list S.t) ->
  ?results_when_no_search: 'model list Lwt.t ->
  model_name: string ->
  ?create_dialog_content: (('model, 'any) Editor.mode -> Page.t Lwt.t) ->
  unit ->
  ('model, 'id option) Component.s
(** Variant of {!make} that only prepares the component. It must still be
    {!Component.initialise}d. This is used for composition with eg.
    {!ComponentList}. *)
