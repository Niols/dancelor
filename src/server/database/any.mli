open Dancelor_common

(* FIXME: merge [Database.Any] and [Database.Entry] which really seems to be
   doing the same thing, except maybe one has functions that can be exposed to
   the controllers and one doesn't? *)

val get_type : actor_id: User_id.t option -> unit Entry.Id.t -> Model_builder.Core.Any.Type.t option Lwt.t

val get_newest : actor_id: User_id.t option -> limit: int -> Any_id.t list Lwt.t
