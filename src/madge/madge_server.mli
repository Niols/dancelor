(** {1 Madge — server-side} *)

open Nes

include module type of Madge

(** {2 Normal behaviour} *)

(** Exception to shortcut execution and return something else immediately. *)
exception Shortcut of (Cohttp.Response.t * Cohttp_lwt.Body.t)

(** The main function of this module. Given a route, a controller and a request,
    attempt to match the request to the route, and, if it succeeds, apply the
    controller. The result of the controller is serialised as the route commands
    and returned as JSON under the form of an Lwt promise compatible with the
    [~callback] argument of {!Cohttp_lwt_unix.Server.make}. *)
val match_apply :
  ('a, 'r Lwt.t, 'r) Route.t ->
  (unit -> 'a) ->
  Request.t ->
  (unit -> (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t) option

module type Endpoints = sig
  include Madge.Endpoints

  type env

  val dispatch : 'a 'r. env -> ('a, 'r Lwt.t, 'r) t -> 'a
  (** A function dispatching routes to controllers. *)
end

module type Apply_controller = sig
  type env
  (** An environment that {!apply_controller} will pass to
      {!Endpoints.dispatch}. Madge does not care what is in it, and it can very
      much be [unit]. *)

  val apply_controller : env -> Request.t -> (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t
  (** A function that, given a request, finds a matching route, dispatches to
      the appropriate controller, and responds correctly. *)
end

module Make_apply_controller : functor (E : Endpoints) -> Apply_controller with type env = E.env

(** {2 Successful non-JSON responses}

    All of these return {!NesVoid.t}, meaning they can only ever be used on a
    route that is never returning normally anyway; otherwise, this would allow
    returning non-JSON on normal routes that expect it. *)

(** Returns the given string. *)
val respond_string : ?content_type: string -> string -> Void.t Lwt.t

(** Returns the given file. *)
val respond_file : fname: string -> Void.t Lwt.t

(** {2 Error responses}

    Their type might seem over-complicated, but it simply means that these
    functions can be used as a format, eg.

    [|
      shortcut_bad_request "This %s is a %s request" "thing" "bad"
    |]

    The [shortcut_*] variants raise an exception. This is normal behaviour if
    they are called within the controller of {!match_apply}. However, outside of
    it, they will leak a private [Shortcut] exception. Prefer using [respond_*]
    variants in those situations. *)

(** Shortcut execution and returns “400 Bad Request” with the given message. *)
val shortcut_bad_request : ('a, Format.formatter, unit, 'any Lwt.t) format4 -> 'a

(** Shortcut execution and returns “403 Forbidden” with the given message. *)
val shortcut_forbidden : ('a, Format.formatter, unit, 'any Lwt.t) format4 -> 'a

(** Variant of {!shortcut_forbidden} for when one purposefully does not want to
    give any information of why that was, typically for user authentication. *)
val shortcut_forbidden_no_leak : unit -> 'any Lwt.t

(** Returns “404 Not Found” with the given message. *)
val respond_not_found : ('a, Format.formatter, unit, (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t) format4 -> 'a
val shortcut_not_found : ('a, Format.formatter, unit, 'any Lwt.t) format4 -> 'a

(** Returns “500 Internal server error” with no message. *)
val respond_internal_server_error : unit -> (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t

(** {2 Generic responses} *)

val respond : SStatusCode.t -> ('a, Format.formatter, unit, (Cohttp.Response.t * Cohttp_lwt.Body.t) Lwt.t) format4 -> 'a
