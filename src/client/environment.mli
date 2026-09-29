(** {1 Environment}

    Client-side environment — persistent information on this run of Dancelor. *)

open Nes
open Dancelor_common
open Model_new
open Html

(** Status of the server. It starts as {!Reachable} but might change to
    {!Unreachable} if the server does not answer. *)
type server_status = Reachable | Unreachable

val server_status : server_status S.t

(** The user that is currently logged in. This queries the server the first time
    it is needed, hence the promise. *)
val actor : Model.User.entry option Lwt.t
val actor_new : User_row.t option Lwt.t

(** For places where we don't want to wait for the promise to resolve, we can
    use {!user_now}. This might however answer [None] even though we are
    connected, if {!user} didn't have time to resolve. *)
val actor_now : unit -> Model.User.entry option

(** The person corresponding to the user that is currently logged in. *)
val person_id : Person_id.t option Lwt.t
val person_row : Person_row.t option Lwt.t

(** Alias for [Lwt.map Option.is_some user]. *)
val is_connected : bool Lwt.t
