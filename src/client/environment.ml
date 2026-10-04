open Nes
open Dancelor_common
open Html

type server_status = Reachable | Unreachable

let (server_status, set_server_status) = S.create Reachable

let () = Madge_client.on_server_reachable := (fun () -> set_server_status Reachable)
let () = Madge_client.on_server_unreachable := (fun () -> set_server_status Unreachable)

let actor = Api.call_exn (User Status)
let actor_id = Option.map Actor.id <$> actor

let is_connected = Lwt.map Option.is_some actor

let actor_now () = match Lwt.state actor with Return actor -> actor | _ -> None

let person = match%lwt actor with None -> lwt_none | Some actor -> lwt actor.person
let person_id = Option.map Person_row.id <$> person
