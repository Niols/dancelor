type actor_role =
  | Owner
  | Viewer
[@@deriving yojson]

let actor_role_of_poly = function
  | `Owner -> Owner
  | `Viewer -> Viewer

type t = {
  is_public: bool;
  actor_role: actor_role option;
  user_is_omniscient_administrator: bool;
}
[@@deriving yojson]

let make ~is_public ~actor_role ~user_is_omniscient_administrator =
  {is_public; actor_role; user_is_omniscient_administrator}

let make_of_poly ~is_public ~actor_role ~user_is_omniscient_administrator =
  make ~is_public ~actor_role: (Option.map actor_role_of_poly actor_role) ~user_is_omniscient_administrator

type view_reason =
  | Public
  | Viewer
  | Owner
  | Omniscient_administrator

let view_reason {is_public; actor_role; user_is_omniscient_administrator} =
  match is_public, actor_role, user_is_omniscient_administrator with
  | true, _, _ -> Public
  | _, Some Owner, _ -> Owner
  | _, Some Viewer, _ -> Viewer
  | _, _, true -> Omniscient_administrator
  | _ -> failwith "Permission.view_reason"

type edit_reason =
  | Owner
  | Omniscient_administrator

let edit_reason {actor_role; user_is_omniscient_administrator; _} =
  match actor_role, user_is_omniscient_administrator with
  | Some Owner, _ -> Some Owner
  | _, true -> Some Omniscient_administrator
  | _ -> None
