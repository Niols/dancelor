open Dancelor_common
open Model_new
open Search_new

val get_row_for : actor_id: User_id.t option -> Book_id.t list -> (Book_id.t -> Book_row.t option) Lwt.t
val get_view : actor_id: User_id.t option -> Book_id.t -> Book_view.t option Lwt.t
val get_form : actor_id: User_id.t option -> Book_id.t -> Book_form.t option Lwt.t
val search : actor_id: User_id.t option -> Book_query.t -> (Book_row.t * float) list Lwt.t

val create : Connection.t -> owner_id: User_id.t -> Book_form.t -> Book_id.t Lwt.t
val update : Connection.t -> Book_id.t -> Book_form.t -> unit Lwt.t
val delete : Connection.t -> Book_id.t -> unit Lwt.t
