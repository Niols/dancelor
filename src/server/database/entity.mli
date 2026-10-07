open Dancelor_common

type visibility = [
  | `Owners_only
  | `Everyone
  | `Select_viewers
]

type visibility_or_public = [visibility | `Public]

val make_public : Connection.t -> Entity_type.t -> 'tag Id.t Lwt.t
(** Make a public entry and return the new id. *)

val make_private : Connection.t -> Entity_type.t -> User_id.t -> 'tag Id.t Lwt.t
(** Make a private entry, handling its access, and return the new id. *)

val touch : Connection.t -> 'tag Id.t -> unit Lwt.t
(** Bumps the `updated_at` field of the entry. *)

val delete : Connection.t -> 'tag Id.t -> unit Lwt.t
(** Deletes the given entry. *)

val get_newest_resources : actor_id: User_id.t option -> limit: int -> Resource_id.t list Lwt.t
(** Return the [~limit] newest elements in the database that the user
    has access to. *)

val get_permission : Connection.t -> actor_id: User_id.t option -> 'tag Id.t -> Permission.t option Lwt.t

val get_actor_roles : Connection.t -> 'tag Id.t -> (User_row.t * Permission.actor_role) list Lwt.t

val set_is_public : Connection.t -> 'tag Id.t -> bool -> unit Lwt.t

val set_actor_roles : Connection.t -> 'tag Id.t -> (User_row.t * Permission.actor_role) list -> unit Lwt.t

val get_type : actor_id: User_id.t option -> Untagged.t Id.t -> Entity_type.t option Lwt.t
