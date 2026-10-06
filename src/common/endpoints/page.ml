(** {1 Client Router} *)

open Nes
open Model

module In_search = struct
  include Fresh.Make(String)
  let of_string = some % inject
  let to_string = project
end

module In_set = struct
  type t = Set_id.t * int
  [@@deriving yojson]
end

(** {2 Endpoints} *)

type (_, _, _) person =
  | Add : ('w, 'w, Void.t) person
  | Edit : (Person_id.t -> 'w, 'w, Void.t) person
  | View : (In_search.t option -> Person_id.t -> 'w, 'w, Void.t) person
[@@deriving madge_wrapped_endpoints]

type (_, _, _) dance =
  | Add : ('w, 'w, Void.t) dance
  | Edit : (Dance_id.t -> 'w, 'w, Void.t) dance
  | View : (In_search.t option -> Dance_id.t -> 'w, 'w, Void.t) dance
[@@deriving madge_wrapped_endpoints]

type (_, _, _) source =
  | Add : ('w, 'w, Void.t) source
  | Edit : (Source_id.t -> 'w, 'w, Void.t) source
  | View : (In_search.t option -> Source_id.t -> 'w, 'w, Void.t) source
[@@deriving madge_wrapped_endpoints]

type (_, _, _) tune =
  | Add : ('w, 'w, Void.t) tune
  | Edit : (Tune_id.t -> 'w, 'w, Void.t) tune
  | View : (In_search.t option -> Tune_id.t -> 'w, 'w, Void.t) tune
[@@deriving madge_wrapped_endpoints]

type (_, _, _) version =
  | Add : (Tune_id.t option -> 'w, 'w, Void.t) version
  | Edit : (Version_id.t -> 'w, 'w, Void.t) version
  | View : (In_search.t option -> In_set.t option -> Version_id.t -> 'w, 'w, Void.t) version
[@@deriving madge_wrapped_endpoints]

type (_, _, _) set =
  | Add : ('w, 'w, Void.t) set
  | Edit : (Set_id.t -> 'w, 'w, Void.t) set
  | View : (In_search.t option -> Set_id.t -> 'w, 'w, Void.t) set
[@@deriving madge_wrapped_endpoints]

type (_, _, _) book =
  | Add : ('w, 'w, Void.t) book
  | Edit : (Book_id.t -> 'w, 'w, Void.t) book
  | View : (In_search.t option -> Book_id.t -> 'w, 'w, Void.t) book
  | Preview : (Book_id.t -> int -> 'w, 'w, Void.t) book
[@@deriving madge_wrapped_endpoints]

type (_, _, _) user =
  | Create : ('w, 'w, Void.t) user
  | Edit : (User_id.t -> 'w, 'w, Void.t) user
  | View : (In_search.t option -> User_id.t -> 'w, 'w, Void.t) user
  | Prepare_reset_password : ('w, 'w, Void.t) user
  | Password_reset : (Username.t -> Password_reset_token_clear.t -> 'w, 'w, Void.t) user
[@@deriving madge_wrapped_endpoints]

type (_, _, _) group =
  | View : (In_search.t option -> Group_id.t -> 'w, 'w, Void.t) group
  | Create : ('w, 'w, Void.t) group
  | Edit : (Group_id.t -> 'w, 'w, Void.t) group
[@@deriving madge_wrapped_endpoints]

type (_, _, _) t =
  | Index : ('w, 'w, Void.t) t
  | Explore : (string -> int -> 'w, 'w, Void.t) t
  | Any : (Untagged.t Id.t -> 'w, 'w, Void.t) t
  (* lifted endpoints *)
  | Person : ('a, 'w, 'r) person -> ('a, 'w, 'r) t
  | Dance : ('a, 'w, 'r) dance -> ('a, 'w, 'r) t
  | Source : ('a, 'w, 'r) source -> ('a, 'w, 'r) t
  | Tune : ('a, 'w, 'r) tune -> ('a, 'w, 'r) t
  | Version : ('a, 'w, 'r) version -> ('a, 'w, 'r) t
  | Set : ('a, 'w, 'r) set -> ('a, 'w, 'r) t
  | Book : ('a, 'w, 'r) book -> ('a, 'w, 'r) t
  | User : ('a, 'w, 'r) user -> ('a, 'w, 'r) t
  | Group : ('a, 'w, 'r) group -> ('a, 'w, 'r) t
[@@deriving madge_wrapped_endpoints]

(** {2 Routes} *)

open Madge

let route_person : type a w r. (a, w, r) person -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module Person_id) @@ void ()
    | Add -> literal "add" @@ void ()
    | Edit -> literal "edit" @@ variable (module Person_id) @@ void ()

let route_dance : type a w r. (a, w, r) dance -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module Dance_id) @@ void ()
    | Add -> literal "add" @@ void ()
    | Edit -> literal "edit" @@ variable (module Dance_id) @@ void ()

let route_source : type a w r. (a, w, r) source -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module Source_id) @@ void ()
    | Add -> literal "add" @@ void ()
    | Edit -> literal "edit" @@ variable (module Source_id) @@ void ()

let route_tune : type a w r. (a, w, r) tune -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module Tune_id) @@ void ()
    | Add -> literal "add" @@ void ()
    | Edit -> literal "edit" @@ variable (module Tune_id) @@ void ()

let route_version : type a w r. (a, w, r) version -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ query_json_opt "in-set" (module In_set) @@ variable (module Version_id) @@ void ()
    | Add -> literal "add" @@ query_json_opt "tune" (module Id.J(Tune_tag)) @@ void ()
    | Edit -> literal "edit" @@ variable (module Version_id) @@ void ()

let route_set : type a w r. (a, w, r) set -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module Set_id) @@ void ()
    | Add -> literal "add" @@ void ()
    | Edit -> literal "edit" @@ variable (module Set_id) @@ void ()

let route_book : type a w r. (a, w, r) book -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module Book_id) @@ void ()
    | Add -> literal "add" @@ void ()
    | Edit -> literal "edit" @@ variable (module Book_id) @@ void ()
    | Preview -> literal "preview" @@ variable (module Book_id) @@ literal "page" @@ variable (module SInt_1) @@ void ()

let route_user : type a w r. (a, w, r) user -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module User_id) @@ void ()
    | Edit -> literal "edit" @@ variable (module User_id) @@ void ()
    | Create -> literal "create" @@ void ()
    | Prepare_reset_password -> literal "prepare-reset-password" @@ void ()
    | Password_reset -> literal "reset-password" @@ query_json "username" (module Username) @@ query_json "token" (module Password_reset_token_clear) @@ void ()

let route_group : type a w r. (a, w, r) group -> (a, w, r) route =
  let open Route in
  function
    | View -> literal "view" @@ query_str_opt "in-search" (module In_search) @@ variable (module Group_id) @@ void ()
    | Edit -> literal "edit" @@ variable (module Group_id) @@ void ()
    | Create -> literal "create" @@ void ()

let route : type a w r. (a, w, r) t -> (a, w, r) route =
  let open Route in
  function
    | Index -> void ()
    | Explore -> literal "explore" @@ query_str_def "q" (module SString) ~def: "" @@ query_json_def "page" (module JInt) ~def: 1 @@ void ()
    | Any -> variable (module Id.S(Untagged)) @@ void ()
    | Person page -> literal "person" @@ route_person page
    | Dance page -> literal "dance" @@ route_dance page
    | Source page -> literal "source" @@ route_source page
    | Tune page -> literal "tune" @@ route_tune page
    | Version page -> literal "version" @@ route_version page
    | Set page -> literal "set" @@ route_set page
    | Book page -> literal "book" @@ route_book page
    | User page -> literal "user" @@ route_user page
    | Group page -> literal "group" @@ route_group page

let href : type a r. (a, Uri.t, r) t -> a = fun page ->
  with_request (route page) @@ fun (module _) request ->
  assert (Request.meth request = GET);
  Request.uri request

let href_book ?in_search book = href (Book View) in_search book
let href_dance ?in_search dance = href (Dance View) in_search dance
let href_person ?in_search person = href (Person View) in_search person
let href_source ?in_search source = href (Source View) in_search source
let href_set ?in_search set = href (Set View) in_search set
let href_tune ?in_search tune = href (Tune View) in_search tune
let href_version ?in_search ?in_set version = href (Version View) in_search in_set version
let href_user ?in_search user = href (User View) in_search user
let href_group ?in_search group = href (Group View) in_search group

let href_any_full ?in_search (any : Any_id.t) =
  match any with
  | Version version -> href_version ?in_search version
  | Set set -> href_set ?in_search set
  | Person person -> href_person ?in_search person
  | Source source -> href_source ?in_search source
  | Dance dance -> href_dance ?in_search dance
  | Book book -> href_book ?in_search book
  | Tune tune -> href_tune ?in_search tune
  | User user -> href_user ?in_search user
  | Group group -> href_group ?in_search group

(** Function that consumes all endpoints and returns nothing. It is meant to be
    used in the catch-all case of a pattern matching. *)
let consume : type a w r. return: w -> (a, w, r) t -> a = fun ~return: value endpoint ->
  match endpoint with
  | Index -> value
  | Any -> const value
  | Book Add -> value
  | Book Edit -> const value
  | Book View -> const2 value
  | Book Preview -> const2 value
  | Dance View -> const2 value
  | Dance Add -> value
  | Dance Edit -> const value
  | Person View -> const2 value
  | Person Add -> value
  | Person Edit -> const value
  | Set View -> const2 value
  | Set Add -> value
  | Set Edit -> const value
  | Source View -> const2 value
  | Source Add -> value
  | Source Edit -> const value
  | Tune View -> const2 value
  | Tune Add -> value
  | Tune Edit -> const value
  | Version View -> const3 value
  | Version Add -> const value
  | Version Edit -> const value
  | Explore -> const2 value
  | User View -> const2 value
  | User Edit -> const value
  | User Create -> value
  | User Prepare_reset_password -> value
  | User Password_reset -> const2 value
  | Group View -> const2 value
  | Group Create -> value
  | Group Edit -> const value

module type Any_id_to_name = sig
  type env
  val get_person_name : env -> Person_id.t -> string Lwt.t
  val get_dance_name : env -> Dance_id.t -> string Lwt.t
  val get_source_name : env -> Source_id.t -> string Lwt.t
  val get_tune_name : env -> Tune_id.t -> string Lwt.t
  val get_version_name : env -> Version_id.t -> string Lwt.t
  val get_set_name : env -> Set_id.t -> string Lwt.t
  val get_book_name : env -> Book_id.t -> string Lwt.t
end

module Make_describe (Any_id_to_name : Any_id_to_name) = struct
  let describe env = fun uri ->
    let describe : type a r. (a, (string * string) option Lwt.t, r) t -> a = function
      | Any -> (fun id -> lwt_some ("any", Id.to_string id))
      | Person View -> (fun _ id -> some % Pair.cons "person" <$> Any_id_to_name.get_person_name env id)
      | Dance View -> (fun _ id -> some % Pair.cons "dance" <$> Any_id_to_name.get_dance_name env id)
      | Source View -> (fun _ id -> some % Pair.cons "source" <$> Any_id_to_name.get_source_name env id)
      | Tune View -> (fun _ id -> some % Pair.cons "tune" <$> Any_id_to_name.get_tune_name env id)
      | Version View -> (fun _ _ id -> some % Pair.cons "version" <$> Any_id_to_name.get_version_name env id)
      | Set View -> (fun _ id -> some % Pair.cons "set" <$> Any_id_to_name.get_set_name env id)
      | Book View -> (fun _ id -> some % Pair.cons "book" <$> Any_id_to_name.get_book_name env id)
      | endpoint -> consume endpoint ~return: lwt_none
    in
    let madge_match_apply_all : (string * string) option Lwt.t wrapped' list -> (unit -> (string * string) option Lwt.t) option =
      List.find_map @@ fun (W' page) ->
      Madge.apply' (route page) (fun () -> describe page) (Request.make ~meth: GET ~uri ~body: "")
    in
    match madge_match_apply_all @@ all' () with
    | Some page -> page ()
    | None -> (* 404 page *) lwt_none
end
