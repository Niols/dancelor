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
val actor : Actor.t option Lwt.t
val actor_id : User_id.t option Lwt.t

(** For places where we don't want to wait for the promise to resolve, we can
    use {!actor_now}. This might however answer [None] even though we are
    connected, if {!actor} didn't have time to resolve yet. *)
val actor_now : unit -> Actor.t option

(** The person corresponding to the actor. *)
val person : Person_row.t option Lwt.t
val person_id : Person_id.t option Lwt.t

(** Alias for [Lwt.map Option.is_some user]. *)
val is_connected : bool Lwt.t
