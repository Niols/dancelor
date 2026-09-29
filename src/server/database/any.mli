open Dancelor_common
open Model_new

(* FIXME: merge [Database.Any] and [Database.Entry] which really seems to be doing the same thing *)

val get : 'any Entry.Id.t -> Model_builder.Core.Any.t option Lwt.t

val get_newest : actor_id: User_id.t option -> limit: int -> Any_id.t list Lwt.t
