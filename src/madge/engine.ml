open Nes

open Request
open Serialisation
open Route_internal

module Log = (val Logs.(src_log (Src.create "madge.engine")): Logs.LOG)

type query = (string * string list) list (* what Uri.t uses *)
type body = (string * Yojson.Safe.t) list (* basically the body of an `Assoc *)

(* route -> request *)

exception Illegal_body_in_get_request

let rec with_request
  : type a w r. string ->
  query ->
  body ->
  (a, w, r) Route.t ->
  ((module JSONABLE with type t = r) -> Request.t -> w) ->
  a
= fun path query body route return ->
  match route with
  | Return {meth; serialiser = (module S)} ->
    (
      let uri = Uri.make ~path ~query () in
      let body =
        if meth = GET then
          (
            if body <> [] then
              raise Illegal_body_in_get_request;
            ""
          )
        else
          Yojson.Safe.to_string @@ `Assoc body
      in
      return (module S) (Request.make ~meth ~uri ~body)
    )
  | Literal {str; rest} ->
    (
      with_request (path ^ "/" ^ str) query body rest return
    )
  | Variable {prefix; serialiser = (module S); suffix; rest} ->
    (fun x ->
      with_request (path ^ "/" ^ prefix ^ Uri.pct_encode (S.to_string x) ^ suffix) query body rest return
    )
  | Query_or_body {kind; name; proxy = _; unproxy; rest} ->
    (fun y ->
      match unproxy y with
      | `Absent ->
        with_request path query body rest return
      | `Present x ->
        let (query, body) =
          match kind with
          | `Query_string(module S) -> ((name, [S.to_string x]) :: query, body)
          | `Query_json(module S) -> ((name, [Yojson.Safe.to_string @@ S.to_yojson x]) :: query, body)
          | `Body(module S) -> (query, (name, S.to_yojson x) :: body)
        in
        with_request path query body rest return
    )

let with_request
  : type a w r. (a, w, r) Route.t ->
  ((module JSONABLE with type t = r) -> Request.t -> w) ->
  a
= fun route return ->
  with_request "" [] [] route return

let uri : type a r. (a, Uri.t, r) Route.t -> a = fun route ->
  with_request route (fun (module _) request -> Request.uri request)

let rec serialiser : type a w r. (a, w, r) Route.t -> (module JSONABLE with type t = r) = function
  | Return {serialiser; _} -> serialiser
  | Literal {rest; _} -> serialiser rest
  | Variable {rest; _} -> serialiser rest
  | Query_or_body {rest; _} -> serialiser rest

let route_result_to_yojson : type a w r. (a, w, r) Route.t -> r -> Yojson.Safe.t = fun route result ->
  let (module S) = serialiser route in
  S.to_yojson result

let route_result_of_yojson : type a w r. (a, w, r) Route.t -> Yojson.Safe.t -> (r, string) result = fun route json ->
  let (module S) = serialiser route in
  S.of_yojson json

(* request -> route *)

(* NOTE: The [controller] is in a thunk to avoid it being ran halfway as we find
   its last argument. It is actually run at the end when all is green. *)
let rec apply
  : type a w r z. (a, w, r) Route.t ->
  (unit -> a) ->
  Request.meth ->
  string list ->
  query ->
  body ->
  ((module JSONABLE with type t = r) -> (unit -> w) -> z) ->
  (unit -> z) option
= fun route controller meth path query body return ->
  match route with
  | Return {meth = meth'; serialiser = (module S)} ->
    (
      Log.debug (fun m -> m "  Return {meth = %s}" (Request.meth_to_string meth'));
      if meth' = meth && path = [] && query = [] && body = [] then
        Some (fun () -> return (module S) controller)
      else
        None
    )
  | Literal {str; rest} ->
    (
      Log.debug (fun m -> m "  Literal {str = %S}" str);
      match path with
      | comp :: path when comp = str -> apply rest controller meth path query body return
      | _ -> None
    )
  | Variable {prefix; serialiser = (module S); suffix; rest} ->
    (
      Log.debug (fun m ->
        m
          "  Variable {prefix = %S; suffix = %S} [path = %a]"
          prefix
          suffix
          Format.(pp_print_list ~pp_sep: (fun fmt () -> fprintf fmt " ") pp_print_string)
          path
      );
      match path with
      | [] -> None
      | comp :: path ->
        Option.bind (String.remove_prefix ~needle: prefix comp) @@ fun comp ->
        Option.bind (String.remove_suffix ~needle: suffix comp) @@ fun comp ->
        Option.bind (S.of_string comp) @@ fun comp ->
        apply rest (fun () -> controller () comp) meth path query body return
    )
  | Query_or_body {kind; name; proxy; unproxy = _; rest} ->
    (
      Log.debug (fun m -> m "  Query_or_body {name = %S}" name);
      let extract_and_parse =
        match (kind, List.extract_assoc_opt name query, List.extract_assoc_opt name body) with
        | ((`Query_string _ | `Query_json _), None, _) ->
          Log.debug (fun m -> m "    Could not find query argument `%s`" name);
          Ok (`Absent, query, body) (* absent: OK *)
        | (`Body _, _, None) ->
          Log.debug (fun m -> m "    Could not find body argument `%s`" name);
          Ok (`Absent, query, body) (* absent: OK *)
        | (`Query_string(module S), Some (value, query), _) ->
          (
            match S.of_string (List.hd value) with
            | Some value -> Ok (`Present value, query, body)
            | None ->
              Log.debug (fun m -> m "    Found query argument `%s` but failed to unserialise it" name);
              Error "unparseable" (* present but unparseable: error *)
          )
        | (`Query_json(module S), Some (value, query), _) ->
          (
            match S.of_yojson (Yojson.Safe.from_string (List.hd value)) with
            | Ok value -> Ok (`Present value, query, body)
            | Error msg | exception (Failure msg) | exception (Yojson.Json_error msg) ->
              Log.debug (fun m -> m "    Found query argument `%s` but failed to unserialise it: %s" name msg);
              Error "unparseable" (* present but unparseable: error *)
          )
        | (`Body(module S), _, Some (value, body)) ->
          (
            match S.of_yojson value with
            | Ok value -> Ok (`Present value, query, body)
            | Error msg ->
              Log.debug (fun m -> m "    Found body argument `%s` but failed to unserialise it: %s" name msg);
              Error "unparseable" (* present but unparseable: error *)
          )
      in
      match extract_and_parse with
      | Error _ -> None (* unparseable: the route does not match *)
      | Ok (maybe_value, query, body) ->
        match proxy maybe_value with
        | `Dont_match -> None
        | `Match value -> apply rest (fun () -> controller () value) meth path query body return
    )

let apply
  : type a w r z. (a, w, r) Route.t ->
  (unit -> a) ->
  Request.t ->
  ((module JSONABLE with type t = r) -> (unit -> w) -> z) ->
  (unit -> z) option
= fun route controller request return ->
  Log.debug (fun m -> m "Madge.apply <route> <controller> <request> <return>");
  let path = List.filter ((<>) "") (String.split_on_char '/' (Uri.path @@ Request.uri request)) in
  let uri_query = Uri.query @@ Request.uri request in
  let body_query =
    let body = Request.body request in
    let body = if body = "" then "{}" else body in
    match Yojson.Safe.from_string body with
    | `Assoc body -> body
    | _ -> assert false
  in
  apply route controller (Request.meth request) path uri_query body_query return

let apply'
  : type a w r. (a, w, r) Route.t ->
  (unit -> a) ->
  Request.t ->
  (unit -> w) option
= fun route controller request ->
  apply route controller request (fun _ f -> f ())
