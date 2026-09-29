open Dancelor_common
open Model_new
open Search_new

val get_row_for : actor_id: User_id.t option -> Book_id.t list -> (Book_id.t -> Book_row.t option) Lwt.t
val get_view : actor_id: User_id.t option -> Book_id.t -> Book_view.t option Lwt.t
val search : actor_id: User_id.t option -> Book_query.t -> (Book_row.t * float) list Lwt.t

(** {2 Legacy} *)

type t = Model_builder.Core.Book.t
type entry = Model_builder.Core.Book.entry

val get : Book_id.t -> entry option Lwt.t

val create : t -> Entry.Access.Private.t -> Book_id.t Lwt.t

val update : Book_id.t -> t -> Entry.Access.Private.t -> unit Lwt.t

val delete : Book_id.t -> unit Lwt.t
