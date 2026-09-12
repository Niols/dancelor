(** {1 Page}

    NOTE: This notion of page is different from the one in the PageRouter.
    FIXME: Rename one of the two! *)

open Dancelor_common
open Model_new
open Html

type t
(** The abstract type of a page in Dancelor. *)

val make :
  ?parent_title: string ->
  ?before_title: Html_types.div_content_fun elt list ->
  title: string Lwt.t ->
  ?subtitles: Html_types.phrasing elt list ->
  ?share: Any_id.t ->
  ?actions: Html_types.li_content_fun elt list Lwt.t list ->
  ?buttons: Html_types.div_content_fun elt list ->
  ?on_load: (unit -> unit) ->
  Html_types.div_content_fun elt list ->
  t
(** Page maker. The [?parent_title] argument is used to build a title of the
    form ["page | parent page"]. It is empty by default. The [?actions] must be
    a list of promises that each return a list of actions; they will be combined
    by waiting for the promises and catenating the results. *)

val make' :
  ?parent_title: string ->
  ?before_title: Html_types.div_content_fun elt list ->
  title: string Lwt.t ->
  ?subtitles: Html_types.phrasing elt list ->
  ?share: Any_id.t ->
  ?actions: Html_types.li_content_fun elt list Lwt.t list ->
  ?buttons: Html_types.div_content_fun elt list ->
  ?on_load: (unit -> unit) ->
  Html_types.div_content_fun elt list ->
  t Lwt.t
(** Variant of {!make} that returns an [Lwt.t] for convenience. *)

val full_title : t -> string S.t
(** Full title, that is the title with the parent component. *)

val render : t -> (unit -> unit) * Html_types.div elt
(** Render the page. *)

val open_dialog :
  ?hide_body_overflow_y: bool ->
  (('result option -> unit) -> t Lwt.t) ->
  'result option Lwt.t
(** [open_dialog f] opens a dialog. [f] is used to create the content of the
    dialog; it receives a [return] function that destroys the dialog and make it
    return. [open_dialog f] returns a promise of either a result or [None] if
    the dialog was closed. *)

val open_dialog' :
  (('result -> unit) -> t Lwt.t) ->
  'result option Lwt.t
(** Variant of {!open_dialog} where there is always a result. *)
