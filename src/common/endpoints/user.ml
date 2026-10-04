open Nes
open Madge
open Model_new
open Search_new
open Model_builder.Core

type (_, _, _) t =
  | Get_row : (User_id.t -> 'w, 'w, User_row.t) t
  | Status : ('w, 'w, Actor.t option) t
  | Sign_in : ((Username.t -> User.Password_clear.t -> bool -> 'w), 'w, Actor.t option) t
  | Sign_out : ('w, 'w, unit) t
  | Create : ((User_create_form.t -> 'w), 'w, User_row.t * User.Password_reset_token_clear.t) t
  | Prepare_reset_password : ((Username.t -> 'w), 'w, User.Password_reset_token_clear.t) t
  | Reset_password : ((Username.t -> User.Password_reset_token_clear.t -> User.Password_clear.t -> 'w), 'w, unit) t
  | Search : (Slice.t -> User_query.t -> 'w, 'w, User_row.t Search_result.t) t
  | Set_omniscience : ((bool -> 'w), 'w, unit) t
[@@deriving madge_wrapped_endpoints]

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Get_row -> variable (module User_id) @@ literal "row" @@ get (module User_row)
    | Status -> literal "status" @@ post (module JOption(Actor))
    | Sign_in -> literal "sign-in" @@ body "username" (module Username) @@ body "password" (module User.Password_clear) @@ body "remember-me" (module JBool) @@ post (module JOption(Actor))
    | Sign_out -> literal "sign-out" @@ post (module JUnit)
    | Create -> literal "create" @@ body "user" (module User_create_form) @@ post (module JPair(User_row)(User.Password_reset_token_clear))
    | Prepare_reset_password -> literal "prepare-reset-password" @@ body "username" (module Username) @@ post (module User.Password_reset_token_clear)
    | Reset_password -> literal "reset-password" @@ body "username" (module Username) @@ body "token" (module User.Password_reset_token_clear) @@ body "password" (module User.Password_clear) @@ post (module JUnit)
    | Search -> literal "search" @@ query_json "slice" (module Slice) @@ query_json "query" (module User_query) @@ get (module Make_search_result(User_row))
    | Set_omniscience -> literal "set-omniscience" @@ body "value" (module JBool) @@ put (module JUnit)
