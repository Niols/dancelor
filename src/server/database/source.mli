open Nes
open Dancelor_common

val get_row_for : Source_id.t list -> (Source_id.t -> Source_row.t option) Lwt.t
val get_view : Source_id.t -> Source_view.t option Lwt.t
val get_form : Source_id.t -> Source_form.t option Lwt.t
val search : Source_query.t -> (Source_row.t * float) list Lwt.t

val create : Connection.t -> Source_form.t -> Source_id.t Lwt.t
val update : Connection.t -> Source_id.t -> Source_form.t -> unit Lwt.t
val delete : Connection.t -> Source_id.t -> unit Lwt.t

val with_cover : Source_id.t -> (string option -> 'a Lwt.t) -> 'a Lwt.t
(** Given a source id, produce a file containing the cover and pass its path to
    the callback. [None] means that there is no cover for this source. *)
