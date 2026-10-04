open Nes
open Dancelor_common

val get_row_for : Person_id.t list -> (Person_id.t -> Person_row.t option) Lwt.t
val get_view : Person_id.t -> Person_view.t option Lwt.t
val get_form : Person_id.t -> Person_form.t option Lwt.t

val search : Person_query.t -> (Person_row.t * float) list Lwt.t

val create : Connection.t -> Person_form.t -> Person_id.t Lwt.t
val update : Connection.t -> Person_id.t -> Person_form.t -> unit Lwt.t
val delete : Connection.t -> Person_id.t -> unit Lwt.t
