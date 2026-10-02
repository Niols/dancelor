open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.permission": Logs.LOG)

(** {2 Common tests and assertions} *)

include Permission_builder
module With_reason = Make(Model.User)
include With_reason

(** The rejection of {!assert_can_get_public}. This may be used by external code
    to behave in the exact same way and avoid leaking information. *)
let reject_can_get () =
  Madge_server.shortcut_not_found "This entry does not exist, or you do not have access to it."

(** {2 Ad-hoc tests and assertions} *)

let is_connected env = lwt (Environment.actor env <> Anonymous)

let assert_is_connected env =
  if%lwt is_connected env then
    (
      Log.debug (fun m -> m "Granting access to %a." Environment.pp env);
      lwt_unit
    )
  else
    (
      Log.info (fun m -> m "Refusing access to %a." Environment.pp env);
      Madge_server.shortcut_forbidden "You do not have permission."
    )

let can_administrate env =
  lwt @@
    match Environment.actor env with
    | Anonymous -> false
    | Signed_in actor -> actor.role = Administrator

let assert_can_administrate env f =
  match Environment.actor env with
  | Anonymous ->
    Log.info (fun m -> m "Refusing admin access to %a." Environment.pp env);
    Madge_server.shortcut_forbidden "You do not have permission to administrate this instance."
  | Signed_in actor ->
    if actor.role = Administrator then
      f actor
    else
      (
        Log.info (fun m -> m "Refusing admin access to %a." Environment.pp env);
        Madge_server.shortcut_forbidden "You do not have permission to administrate this instance."
      )
