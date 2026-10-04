(** {1 User} *)

open Nes
open Dancelor_common
open Model_new
open Search_new

(** {2 Components} *)

module Password_hashed : Fresh.T with type base = HashedSecret.t
module Password_reset_token_hashed : Fresh.T with type base = HashedSecret.t
module Remember_me_key : Fresh.T with type base = string
module Remember_me_token_clear : Fresh.T with type base = string
module Remember_me_token_hashed : Fresh.T with type base = HashedSecret.t

(** {2 User} *)

type t = Entry.User.t
type entry = t Entry.public

(** {2 Queries} *)

val get_row_for : User_id.t list -> (User_id.t -> User_row.t option) Lwt.t
val get_row : User_id.t -> User_row.t option Lwt.t
val get_actor : User_id.t -> Actor.t option Lwt.t
val search : User_query.t -> (User_row.t * float) list Lwt.t

(** {2 From username} *)

val get_actor_from_username : Username.t -> Actor.t option Lwt.t
val get_password_from_username : Username.t -> Password_hashed.t option Lwt.t
val get_password_reset_token_from_username : Username.t -> (Password_reset_token_hashed.t * Datetime.t) option Lwt.t

(** {2 FIXME: Clean up the following} *)

val create :
  username: Username.t ->
  role: Entry.User.role ->
  github_handle: string option ->
  password_reset_token_hash: Password_reset_token_hashed.t ->
  password_reset_token_max_date: Datetime.t ->
  User_id.t Lwt.t

val set_password_reset_token : User_id.t -> Password_reset_token_hashed.t -> Datetime.t -> unit Lwt.t
(** For the given user, set the password reset token and max date, and clear the
    password and remember me tokens. *)

val set_password : User_id.t -> Password_hashed.t -> unit Lwt.t
(** For the given user, set the password and clear the password reset token. *)

val find_remember_me_token : User_id.t -> Remember_me_key.t -> (Remember_me_token_hashed.t * Datetime.t) option Lwt.t
val add_remember_me_token : User_id.t -> Remember_me_key.t -> Remember_me_token_hashed.t -> Datetime.t -> unit Lwt.t
val remove_one_remember_me_token : User_id.t -> Remember_me_key.t -> unit Lwt.t
val remove_all_remember_me_tokens : User_id.t -> unit Lwt.t

val set_omniscience : User_id.t -> bool -> unit Lwt.t
(** For the given user, set omniscience to the given boolean. *)
