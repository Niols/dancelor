open Dancelor_common

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

val make_public : Connection.t -> type_ -> 'tag Id.t Lwt.t
(** Make a public entry and return the new id. *)

val make_private_new : Connection.t -> type_ -> User_id.t -> 'tag Id.t Lwt.t
(** Make a private entry, handling its access, and return the new id. *)

val touch : Connection.t -> 'tag Id.t -> unit Lwt.t
(** Bumps the `updated_at` field of the entry. *)

val delete : Connection.t -> 'tag Id.t -> unit Lwt.t
(** Deletes the given entry. *)

val get_newest : actor_id: User_id.t option -> limit: int -> Any_id.t list Lwt.t
(** Return the [~limit] newest elements in the database that the user
    has access to. *)

val get_permission : Connection.t -> actor_id: User_id.t option -> 'tag Id.t -> Permission.t option Lwt.t

val get_actor_roles : Connection.t -> 'tag Id.t -> (User_row.t * Permission.actor_role) list Lwt.t

val set_is_public : Connection.t -> 'tag Id.t -> bool -> unit Lwt.t

val set_actor_roles : Connection.t -> 'tag Id.t -> (User_row.t * Permission.actor_role) list -> unit Lwt.t
