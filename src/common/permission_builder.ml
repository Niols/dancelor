open Nes

let (<|>) x y = Option.(choose ~tie: first) x y

(** {2 Reasons why users can do things} *)

(** Reasons why a user can get a public element. *)
type can_get_public =
  | Everyone (** everyone can see a public element *)

(** Reasons why a user can create a public element. *)
type can_create_public =
  | Connected

(** Reasons why a user can update a public element. *)
type can_update_public =
  | Maintainer (** you can update this entry because you are a database maintainer *)
  | Administrator (** you can update this entry because you are an administrator *)

(** Reasons why a user can delete a public element. *)
type can_delete_public = can_update_public

(** Reasons why a user can get a private element. *)
type can_get_private =
  | Everyone (** everyone can see this entry *)
  | Owner (** you can see this entry because you are its owner *)
  | Viewer (** you can see this entry because its owner marked you as a viewer *)
  | Omniscient_administrator (** you can see this entry because you are an administrator with omniscience enabled *)
[@@deriving yojson]

(** Reasons why a user can create a private element. *)
type can_create_private =
  | Connected

(** Reasons why a user can update a private element. *)
type can_update_private =
  | Owner (** you can update this entry because you are its owner *)
  | Omniscient_administrator (** you can update this entry because you are an administrator with omniscience enabled *)

(** Reasons why a user can delete a private element. *)
type can_delete_private = can_update_private

(** {2 Functions to decide whether users can do things} *)

type user = Entry.user Entry.public option

module type S = sig
  (** Whether the given user can get public elements. As the name suggests, they
      are public, so anyone, including anonymous users. *)
  val can_get_public : user -> 'value Entry.public -> can_get_public option
  val can_get_public_new : user -> 'value -> can_get_public option

  (** Whether the given user can create public elements. This is any connected
      user. *)
  val can_create_public : user -> can_create_public option

  (** Whether the given user can update public elements. Those are only database
      maintainers and administrators. We require a witness entry, which is not
      used, but is meant to force us to check that the entry exists, and that it
      is indeed public (at type-checking time). *)
  val can_update_public : user -> 'value Entry.public -> can_update_public option
  val can_update_public_new : user -> 'value -> can_update_public option

  (** Whether the given user can delete public elements. Those are only database
      maintainers and administrators. This is the same as {!can_update_public}. *)
  val can_delete_public : user -> 'value Entry.public -> can_delete_public option
  val can_delete_public_new : user -> 'value -> can_delete_public option

  (** Whether the given user can get private elements. This is everyone if the
      visibility is set like that, or the selected viewers if there are some, or
      the owners of the entry or an omniscient administrator. *)
  val can_get_private : user -> 'value Entry.private_ -> can_get_private option

  (** Whether the given user can create “private” elements. This is anyone that
      is connected. *)
  val can_create_private : user -> can_create_private option

  (** Whether the given user can update a specific private element. This is one
      of the owners of the entry, or an omniscient administrator. *)
  val can_update_private : user -> 'value Entry.private_ -> can_update_private option

  (** Whether the given user can delete a specific private element. This is one
      of the owners of the entry, or an administrator. This is exactly the same
      as {!can_update_private}. *)
  val can_delete_private : user -> 'value Entry.private_ -> can_delete_private option
end

module Make (User : Model_builder.Signature.User) : S = struct
  let is_connected user = user <> None

  let can_get_public _user _entry : can_get_public option = Some Everyone
  let can_get_public_new _user _entry : can_get_public option = Some Everyone

  let can_create_public user : can_create_public option = if is_connected user then Some Connected else None

  (* FIXME: grace period during which anyone can edit *)
  let can_update_public user _entry : can_update_public option =
    Option.bind user (fun user ->
      ((if User.is_maintainer' user then Some Maintainer else None) : can_update_public option)
      <|> ((if User.is_administrator' user then Some Administrator else None) : can_update_public option)
    )

  let can_update_public_new user entry : can_update_public option =
    can_update_public user entry

  (* FIXME: grace period during which anyone can edit *)
  let can_delete_public user entry : can_delete_public option =
    can_update_public user entry

  let can_delete_public_new user entry : can_delete_public option =
    can_delete_public user entry

  let can_get_private user entry : can_get_private option =
    let access = Entry.access entry in
    let is_public = Entry.Access.Private.is_public access in
    (if is_public then Some Everyone else None)
    <|> Option.bind user (fun user ->
        (if List.exists (Entry.Id.equal' (Entry.id user)) (Entry.Access.Private.owners access) then Some (Owner : can_get_private) else None)
        <|> (if List.exists (Entry.Id.equal' (Entry.id user)) (Entry.Access.Private.viewers access) then Some (Viewer : can_get_private) else None)
        <|> (if User.is_omniscient_administrator' user then Some Omniscient_administrator else None)
      )

  let can_create_private user = if user <> None then Some Connected else None

  let can_update_private user entry : can_update_private option =
    let access = Entry.access entry in
    Option.bind user (fun user ->
      (if List.exists (Entry.Id.equal' (Entry.id user)) (Entry.Access.Private.owners access) then Some Owner else None)
      <|> (if User.is_omniscient_administrator' user then Some Omniscient_administrator else None)
    )

  let can_delete_private user entry : can_delete_private option = can_update_private user entry
end
