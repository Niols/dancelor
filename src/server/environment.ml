open NesUnix
open Model_unix

module Log = (val Logs.src_log @@ Logs.Src.create "server.environment": Logs.LOG)

let session_max_age = 43200 (* 43200 seconds = 12 hours *)
let remember_me_token_max_age = 15552000 (* 15552000 seconds = 6 * 30 days *)

type actor =
  | Anonymous
  | Signed_in of Actor.t
[@@deriving variants]

type session = {
  actor: actor;
  expires: Datetime.t;
}

let make_new_session () =
  lwt {actor = Anonymous; expires = Datetime.make_in_the_future (float_of_int session_max_age)}

(** Refresh the session by getting the actor again from the database and bumping
    the expiry date. *)
let refresh_session session =
  let%lwt actor =
    match session.actor with
    | Anonymous -> lwt Anonymous
    | Signed_in actor -> signed_in % Option.get <$> Database.User.get_actor actor.id
  in
  let expires = Datetime.make_in_the_future (float_of_int session_max_age) in
  lwt {actor; expires}

type t = {
  session_id: string;
  session: session ref;
  response_cookies: (Cohttp.Header.t -> Cohttp.Header.t) list ref;
}
[@@deriving fields]

let pp fmt env =
  fpf
    fmt
    "%s [%s, expires %a]"
    (
      match !(env.session).actor with
      | Anonymous -> "<anynomous>"
      | Signed_in actor -> Id.to_string actor.id
    )
    env.session_id
    Datetime.pp
    !(env.session).expires

let actor env = (!(env.session)).actor

let actor_id env =
  match actor env with
  | Anonymous -> None
  | Signed_in actor -> Some actor.id

let register_response_cookie env cookie =
  env.response_cookies := cookie :: !(env.response_cookies)

let add_cookie ?max_age ?path ?(secure = false) ?(httpOnly = false) key value headers =
  Cohttp.Header.add headers "Set-Cookie" @@
  (key ^ "=" ^ value) ^
  (match path with None -> "" | Some path -> "; Path=" ^ path) ^
  (match secure with false -> "" | true -> "; Secure") ^
  (match httpOnly with false -> "" | true -> "; HttpOnly") ^
    (match max_age with None -> "" | Some max_age -> "; Max-Age=" ^ string_of_int max_age)

let delete_cookie ?path key headers =
  Cohttp.Header.add headers "Set-Cookie" @@
  (key ^ "=deleted") ^
  (match path with None -> "" | Some path -> "; Path=" ^ path) ^
  "; Expires=Thu, 01 Jan 1970 00:00:00 GMT"

(* A hash table linking session ids to sessions. *)
let sessions : (string, session) Hashtbl.t = Hashtbl.create 8

let set_actor env actor =
  env.session := {!(env.session) with actor = Signed_in actor};
  Hashtbl.replace sessions env.session_id !(env.session)

(* Given an environment, check whether we should log in a user via their
   remember me token. This is meant to be used in {!make}, before returning a
   transient environment. *)
let process_remember_me_cookie env remember_me_cookie =
  match String.split_3_on_char ':' remember_me_cookie with
  | None -> lwt_unit
  | Some (id, key, token) ->
    let key = Remember_me_key.inject key in
    let token = Remember_me_token_clear.inject token in
    Log.info (fun m -> m "Attempt to get remembered with id `%s`." id);
    match Id.of_string id with
    | None ->
      Log.info (fun m -> m "Rejecting because id is not valid.");
      register_response_cookie env (delete_cookie ~path: "/" "rememberMe");
      lwt_unit
    | Some id ->
      match%lwt Database.User.get_actor id with
      | None ->
        Log.info (fun m -> m "Rejecting because of wrong username.");
        register_response_cookie env (delete_cookie ~path: "/" "rememberMe");
        lwt_unit
      | Some actor ->
        match%lwt Database.User.find_remember_me_token actor.id key with
        | None ->
          Log.info (fun m -> m "Rejecting because user does not have the “remember me” key `%a`." Remember_me_key.pp key);
          register_response_cookie env (delete_cookie ~path: "/" "rememberMe");
          lwt_unit
        | Some (_, token_max_date) when Datetime.in_the_past token_max_date ->
          Log.info (fun m -> m "Rejecting because token is too old.");
          Database.User.remove_one_remember_me_token actor.id key;%lwt
          register_response_cookie env (delete_cookie ~path: "/" "rememberMe");
          lwt_unit
        | Some (hashed_token, _) when not @@ HashedSecret.is ~clear: (Remember_me_token_clear.project token) (Remember_me_token_hash.project hashed_token) ->
          Log.info (fun m -> m "Rejecting because tokens do not match.");
          (* someone got their hand on a "remember me" key - invalidate all known tokens *)
          (* NOTE: Similar to password reset tokens, we should be able to compare directly but need to project. *)
          Database.User.remove_all_remember_me_tokens actor.id;%lwt
          register_response_cookie env (delete_cookie ~path: "/" "rememberMe");
          lwt_unit
        | Some _ ->
          set_actor env actor;
          Log.info (fun m -> m "Accepted sign in for %a." pp env);
          lwt_unit

let from_request request =
  Log.debug (fun m -> m "In Environment.from_request...");
  let headers = Cohttp.Request.headers request in
  Log.debug (fun m -> m "Header:@\n%a" Cohttp.Header.pp_hum headers);
  let cookies =
    match Cohttp.Header.get headers "Cookie" with
    | None -> []
    | Some cookies ->
      let cookies = Str.split (Str.regexp "[ \t]*;[ \t]*") cookies in
      List.filter_map (String.split_2_on_char '=') cookies
  in
  Log.debug (fun m -> m "Got cookies: %a" (Format.pp_print_list ~pp_sep: (fun fmt () -> fpf fmt "@\n  - ") (fun fmt (k, v) -> fpf fmt "%s -> %s" k v)) cookies);
  let session_id = Option.value' (List.assoc_opt "session" cookies) ~default: uid in
  Log.debug (fun m -> m "Session id: %s" session_id);
  let%lwt session =
    match Hashtbl.find_opt sessions session_id with
    | None -> Log.debug (fun m -> m "No session: creating a new one."); make_new_session ()
    | Some session when Datetime.in_the_past session.expires -> Log.debug (fun m -> m "Old session: creating a new one."); make_new_session ()
    | Some session -> Log.debug (fun m -> m "Live session: updating."); refresh_session session
  in
  let session = ref session in
  let response_cookies = ref [] in
  let env = {session_id; session; response_cookies} in
  (
    match !session.actor, List.assoc_opt "rememberMe" cookies with
    | Anonymous, Some remember_me_cookie ->
      Log.debug (fun m -> m "Processing “remember me” cookie.");
      process_remember_me_cookie env remember_me_cookie
    | _ -> lwt_unit
  );%lwt
  Log.debug (fun m -> m "Environment.from_request done; actor is: %a." pp env);
  Hashtbl.replace sessions session_id !session;
  lwt env

let update_reponse_headers response f =
  let open Cohttp in
  (* FIXME: not super robust if fields get added to the response. *)
  Response.make
    ~version: (Response.version response)
    ~status: (Response.status response)
    ~encoding: (Response.encoding response)
    ~headers: (f @@ Response.headers response)
    ()

type session_cookie_action =
  | Add_session_cookie
  | Skip_session_cookie

let to_response sca env (response, body) = (
  (
    update_reponse_headers response @@ fun headers ->
    let headers =
      match sca with
      | Add_session_cookie -> add_cookie ~path: "/" ~secure: true ~httpOnly: true "session" env.session_id headers
      | Skip_session_cookie -> headers
    in
    List.fold_left (fun headers response_cookie -> response_cookie headers) headers !(env.response_cookies)
  ),
  body
)

let with_ sca request f =
  let%lwt env = from_request request in
  to_response sca env <$> f env

let with_' request f =
  let%lwt env = from_request request in
  let%lwt (sca, resp) = f env in
  lwt @@ to_response sca env resp

let sign_in env (actor : Actor.t) ~remember_me =
  set_actor env actor;
  Lwt.if_' remember_me (fun () ->
    let key = Remember_me_key.make () in
    let token = Remember_me_token_clear.make () in
    (
      (* NOTE: We should use Remember_me_token_hashed.make here, but HashedSecret.make
         is only available on the server side (NesHashedSecretUnix), not in common code. *)
      let hashed_token = Remember_me_token_hash.make ~clear: token in
      (* the max date stored in database is one more minute than the max age that
         will be sent as cookie, to be sure not to lie to our clients *)
      let max_date = Datetime.make_in_the_future (float_of_int @@ 60 + remember_me_token_max_age) in
      (* let remember_me_token = Some (hashed_token, max_date) in *)
      Database.User.add_remember_me_token actor.id key hashed_token max_date
    );%lwt
    register_response_cookie
      env
      (
        add_cookie
          ~path: "/"
          ~secure: true
          ~httpOnly: true
          "rememberMe"
          (Id.to_string actor.id ^ ":" ^ Remember_me_key.project key ^ ":" ^ Remember_me_token_clear.project token)
          ~max_age: remember_me_token_max_age
      );
    lwt_unit
  )

let sign_out env (actor : Actor.t) =
  let session = {!(env.session) with actor = Anonymous} in
  Hashtbl.replace sessions env.session_id session;
  env.session := session;
  Database.User.remove_all_remember_me_tokens actor.id;%lwt
  register_response_cookie env (delete_cookie ~path: "/" "rememberMe");
  lwt_unit

type cache_key = {
  session_id: string;
  actor: actor;
}
[@@ocaml.warning "-69"]
(* NOTE: We disable warning 69, “unused record field”, because the goal is to
   generate these keys so that they can be hashed or tested for physical
   equality; we will never use them directly. *)

let cache_key env : cache_key =
  let {session_id; session; response_cookies = _} : t = env in
  let {actor; expires = _} : session = !session in
    {session_id; actor}
