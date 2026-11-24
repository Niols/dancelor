open Nes
include Madge

type error =
  | Http of {request: Request.t; status: Cohttp.Code.status_code; message: string}
  | Server_unreachable of {request: Request.t; status: Cohttp.Code.status_code}
  | Body_unserialisation of {body: string; message: string}

exception Error of error

type error_response = {message: string} [@@deriving yojson]

let max_attempts = 10 (* up to ~2 minutes *)

let on_server_reachable = ref (fun () -> ())
let on_server_unreachable = ref (fun () -> ())

let call_retry ~retry (request : Request.t) : (Response.t, error) result Lwt.t =
  let meth = Request.meth_to_cohttp_code_meth (Request.meth request) in
  let body = Cohttp_lwt.Body.of_string (Request.body request) in
  let rec call_retry attempt =
    let%lwt (response, body) = Cohttp_lwt_jsoo.Client.call meth (Request.uri request) ~body in
    let status = Cohttp.Response.status response in
    if List.mem (Cohttp.Code.code_of_status status) [0; 502; 503; 504] then
      (
        !on_server_unreachable ();
        if attempt >= max_attempts then
          Lwt.return_error @@ Server_unreachable {request; status}
        else
          let delay = (2. ** (float_of_int attempt) +. Random.float 2.) /. 8. in
          Js_of_ocaml_lwt.Lwt_js.sleep delay;%lwt
          call_retry (attempt + 1)
      )
    else
      (
        !on_server_reachable ();
        let%lwt body = Response.body_of_lwt body in
        lwt_ok (response, body)
      )
  in
  call_retry (if retry then 1 else max_int)

(** Maximal time a request waits before its batch goes. *)
let batch_delay = 0.01 (* 10 ms *)

(** Maximal batch size; when reached, we send it. *)
let batch_size = 100

type batch_state =
  | Gathering_batch of (Request.t * (Response.t, error) result Lwt.u) list
  | Idle

let batch_state = ref Idle

let batch_route = ref None

let initialise_batch_route r =
  match !batch_route with
  | None -> batch_route := Some r
  | Some _ -> failwith "Madge_client: batch route initialised twice"

let batch_route () =
  match !batch_route with
  | None -> failwith "Madge_client: processed a batch, but batch route has not been initialised"
  | Some batch_route -> batch_route

type request_list = Request.t list
[@@deriving yojson]

type response_list = Response.t list
[@@deriving yojson]

let process_batch = function
  | [(request, resolver)] ->
    let%lwt response = call_retry ~retry: true request in
    Lwt.wakeup_later resolver response;
    lwt_unit
  | batch ->
    let (requests, resolvers) = List.split (List.rev batch) in
    with_request
      (batch_route ())
      (fun _ batched_request ->
        match%lwt call_retry ~retry: true batched_request with
        | Error error ->
          let batch_error =
            match error with
            | Server_unreachable details -> Server_unreachable details
            | Http {request; status; message} -> Http {request; status; message = "Batched request: " ^ message}
            | Body_unserialisation {body; message} -> Body_unserialisation {body; message = "Batched request: " ^ message}
          in
          List.iter (fun resolver -> Lwt.wakeup_later resolver (Result.Error batch_error)) resolvers;
          lwt_unit
        | Ok batched_response ->
          let responses = Result.get_ok @@ response_list_of_yojson @@ Yojson.Safe.from_string @@ Cohttp.Body.to_string @@ snd batched_response in
          List.iter2
            (fun response resolver -> Lwt.wakeup_later resolver (Ok response))
            responses
            resolvers;
          lwt_unit
      )
      requests

let call_batch (request : Request.t) : (Response.t, error) result Lwt.t =
  let (promise, resolver) = Lwt.wait () in
  let batch_elem = (request, resolver) in
  batch_state :=
    (
      match !batch_state with
      | Gathering_batch batch when List.length batch < batch_size ->
        Gathering_batch (batch_elem :: batch)
      | Gathering_batch batch ->
        Lwt.async (fun () -> process_batch batch);
        Gathering_batch [batch_elem]
      | Idle ->
        Lwt.async (fun () ->
          Js_of_ocaml_lwt.Lwt_js.sleep batch_delay;%lwt
          match !batch_state with
          | Idle -> lwt_unit
          | Gathering_batch batch ->
            batch_state := Idle;
            process_batch batch
        );
        Gathering_batch [batch_elem]
    );
  promise

(** Whether to use the batching mechanism of Madge. *)
let do_batch = false

(** A very short-lived cache to avoid performing the exact same request several times in a row. *)
let cache : (Request.t, (Response.t, error) result Lwt.t) Cache.t = Cache.create ~lifetime: (Time.duration_of_seconds 1.) ()

let call_gen
  : type a r z. ?retry: bool ->
  (a, z, r) Route.t ->
  ((r, error) result Lwt.t -> z) ->
  a
= fun ?(retry = true) route cont ->
  with_request route @@ fun (module R) request ->
  cont @@
    let%rlwt (response, body) =
      Cache.use ~cache ~key: request ~if_: Request.(is_safe @@ meth request) @@ fun () ->
      if do_batch && retry then
        call_batch request
      else
        call_retry ~retry request
    in
    let status = Cohttp.Response.status response in
    let body = Cohttp.Body.to_string body in
    let%rlwt json_body =
      try
        Lwt.return_ok @@ Yojson.Safe.from_string body
      with
        | Yojson.Json_error message ->
          Lwt.return_error @@ Body_unserialisation {body; message = "not JSON: " ^ message}
    in
    if Cohttp.(Code.(is_success (code_of_status status))) then
      (
        match R.of_yojson json_body with
        | Error message -> Lwt.return_error @@ Body_unserialisation {body; message}
        | Ok body -> Lwt.return_ok body
      )
    else
      (
        match error_response_of_yojson json_body with
        | Error message -> Lwt.return_error @@ Body_unserialisation {body; message = "expected an error, but " ^ message}
        | Ok {message} -> Lwt.return_error @@ Http {request; status; message}
      )

let call
  : type a r. ?retry: bool -> (a, (r, error) result Lwt.t, r) Route.t -> a
= fun ?retry route -> call_gen ?retry route id

let call_exn
  : type a r. ?retry: bool -> (a, r Lwt.t, r) Route.t -> a
= fun ?retry route -> call_gen ?retry route @@ Lwt.map @@ Result.fold ~ok: Fun.id ~error: (fun e -> raise (Error e))
