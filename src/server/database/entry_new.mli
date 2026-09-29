open Dancelor_common
open Model_new

type type_ = [
  | `Book
  | `Dance
  | `Person
  | `Set
  | `Source
  | `Tune
  | `User
  | `Version
]

type visibility = [
  | `Owners_only
  | `Everyone
  | `Select_viewers
]

type visibility_or_public = [visibility | `Public]

val make_public : Connection.t -> type_ -> 'any Entry.Id.t Lwt.t
(** Make a public entry and return the new id. *)

val make_private : Connection.t -> type_ -> Entry.Access.Private.t -> 'any Entry.Id.t Lwt.t
(** Make a private entry, handling its access, and return the new id. *)

val touch : Connection.t -> 'any Entry.Id.t -> unit Lwt.t
(** Bumps the `updated_at` field of the entry. *)

val update_private_access : Connection.t -> 'any Entry.Id.t -> Entry.Access.Private.t -> unit Lwt.t
(** Updates the access information for the given entry. *)

val get_type : Connection.t -> 'any Entry.Id.t -> type_ option Lwt.t
(** Given an id, try to find the corresponding model in the global table. *)

val delete : Connection.t -> 'any Entry.Id.t -> unit Lwt.t
(** Deletes the given entry. *)

val get_newest : actor_id: User_id.t option -> limit: int -> Any_id.t list Lwt.t
(** Return the [~limit] newest elements in the database that the user
    has access to. *)
