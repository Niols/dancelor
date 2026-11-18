(** {1 Engine}

    The heart of Madge, where we link routes and requests. *)

open Serialisation

(** {2 from route to request} *)

val uri : ('a, Uri.t, 'r) Route.t -> 'a
(** Easiest way to use a route: transform it into a URI. The ['a] parameter
    corresponds to the function of that route, with [Uri.t] as return type. For
    instance, if [r] has type [(int -> float -> 'w, 'w, 'r) route], then [uri r]
    will have type [int -> float -> Uri.t]. *)

val with_request :
  ('a, 'w, 'r) Route.t ->
  ((module JSONABLE with type t = 'r) -> Request.t -> 'w) ->
  'a
(** Generic way to use a route. Given a route and a continuation, create a
    request from the route, pass that request to the continuation, and return
    the resulting value. For instance, {!uri} is simply [process route (fun
    (module _) {uri; _} -> uri)]. *)

val route_result_to_yojson : ('a, 'w, 'r) Route.t -> 'r -> Yojson.Safe.t
val route_result_of_yojson : ('a, 'w, 'r) Route.t -> Yojson.Safe.t -> ('r, string) result

(** {2 from request to route} *)

val apply' :
  ('a, 'w, 'r) Route.t ->
  (unit -> 'a) ->
  Request.t ->
  (unit -> 'w) option
(** Given a route, a controller, and a request, check whether the route matches
    the request. If so, construct a thunk that calls the controller with the
    correct arguments. Otherwise, return [None]. *)

val apply :
  ('a, 'w, 'r) Route.t ->
  (unit -> 'a) ->
  Request.t ->
  ((module JSONABLE with type t = 'r) -> (unit -> 'w) -> 'z) ->
  (unit -> 'z) option
(** Given a route, a controller, a request, and a continuation, check whether
    the route matches. If so, construct a thunk that calls the controller with
    the correct arguments and passes it to the continuation. Otherwise, return
    [None]. For instance, {!apply'} is simply [apply route controller request
    (fun _ f -> f ())]. *)
