open Nes
open Dancelor_common

val get_row_for : Version_id.t list -> (Version_id.t -> Version_row.t option) Lwt.t
val get_view : Version_id.t -> Version_view.t option Lwt.t
val get_form : Version_id.t -> Version_form.t option Lwt.t
val get_views_for_tune : Tune_id.t -> Version_view.t list Lwt.t
val get_all_forms : unit -> Version_form.t list Lwt.t
val get_content : Version_id.t -> Model_builder.Core.Version.Content.t option Lwt.t

val search : Version_query.t -> (Version_row.t * float) list Lwt.t

val create : Connection.t -> Version_form.t -> Version_id.t Lwt.t
val update : Connection.t -> Version_id.t -> Version_form.t -> unit Lwt.t
val delete : Connection.t -> Version_id.t -> unit Lwt.t
