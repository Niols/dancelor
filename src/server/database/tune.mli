open Nes
open Dancelor_common

val get_row_for : Tune_id.t list -> (Tune_id.t -> Tune_row.t option) Lwt.t
val get_rows_for_dance : Dance_id.t -> Tune_row.t list Lwt.t
val get_view : Tune_id.t -> Tune_view.t option Lwt.t
val get_form : Tune_id.t -> Tune_form.t option Lwt.t
val search : Tune_query.t -> (Tune_row.t * float) list Lwt.t

val create : Connection.t -> Tune_form.t -> Tune_id.t Lwt.t
val update : Connection.t -> Tune_id.t -> Tune_form.t -> unit Lwt.t
val delete : Connection.t -> Tune_id.t -> unit Lwt.t
