open Nes
open Madge

(** Abstract type of the response to a registration endpoint, parametrised
    by the payload. *)
type 'payload registration_response =
  | Already_succeeded of 'payload (** for when the job is cached and has already succeeded; avoids an extra call to check the status *)
  | Registered of 'payload (** the job has been registered (whether it happened right now or already before) *)
[@@deriving yojson]

let map_registration_response f = function
  | Already_succeeded x -> Already_succeeded (f x)
  | Registered x -> Registered (f x)

module Status = struct
  type t =
    | Pending (** the server knows of the job *)
    | Running of string list (** the server is running the job; carries the logs *)
    | Failed of string list (** the job has failed; carries the logs *)
    | Succeeded (** the job has succeeded *)
  [@@deriving yojson]
end

type (_, _, _) t =
  | Status : (Job_id.t -> 'w, 'w, Status.t) t
  | File : (Job_id.t -> NesSlug.t -> 'w, 'w, Void.t) t
[@@deriving madge]

module Registration_response
    (Payload : Madge.JSONABLE)
  : Madge.JSONABLE with type t = Payload.t registration_response
= struct
  type t = Payload.t registration_response [@@deriving yojson]
end

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Status -> variable (module Job_id) @@ post (module Status)
    | File -> variable (module Job_id) @@ variable (module SSlug) @@ void ()
