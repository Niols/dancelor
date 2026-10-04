open Nes
open Dancelor_common
open Model_new
open Search_new

val get_row_for : Dance_id.t list -> (Dance_id.t -> Dance_row.t option) Lwt.t
val get_view : Dance_id.t -> Dance_view.t option Lwt.t
val get_form : Dance_id.t -> Dance_form.t option Lwt.t

val search : Dance_query.t -> (Dance_row.t * float) list Lwt.t

val create : Connection.t -> Dance_form.t -> Dance_id.t Lwt.t
val update : Connection.t -> Dance_id.t -> Dance_form.t -> unit Lwt.t
val delete : Connection.t -> Dance_id.t -> unit Lwt.t
