open Nes
open Dancelor_common
open Model_new
open Html

type server_status = Reachable | Unreachable

let (server_status, set_server_status) = S.create Reachable

let () = Madge_client.on_server_reachable := (fun () -> set_server_status Reachable)
let () = Madge_client.on_server_unreachable := (fun () -> set_server_status Unreachable)

let actor = Api.call_exn (User Status)
let actor_new = Api.call_exn (User Status_new)
let actor_id = Option.map User_row.id <$> actor_new

let is_connected = Lwt.map Option.is_some actor

let actor_now () = match Lwt.state actor with Return actor -> actor | _ -> None

let person_row =
  match%lwt actor with
  | None -> lwt_none
  | Some actor -> Api.call_exn (Person For_user) (Entry.id actor)

let person_id =
  let%lwt person = person_row in
  lwt @@ Option.map (fun p -> p.Person_row.id) person
