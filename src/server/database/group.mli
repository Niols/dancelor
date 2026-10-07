(** {1 Group} *)

open Nes
open Model_unix

(** {2 Queries} *)

val get_row_for : Group_id.t list -> (Group_id.t -> Group_row.t option) Lwt.t
val get_row : Group_id.t -> Group_row.t option Lwt.t
val get_view : Group_id.t -> Group_view.t option Lwt.t
val get_form : Group_id.t -> Group_form.t option Lwt.t
val search : Group_query.t -> (Group_row.t * float) list Lwt.t

val create : Connection.t -> Group_form.t -> Group_id.t Lwt.t
val update : Connection.t -> Group_id.t -> Group_form.t -> unit Lwt.t
