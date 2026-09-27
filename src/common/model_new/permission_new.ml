type actor_role =
  | Owner
  | Viewer
[@@deriving eq, yojson]

let actor_role_of_poly = function
  | `Owner -> Owner
  | `Viewer -> Viewer

type t = {
  entry_is_public: bool;
  actor_role: actor_role option;
  actor_is_omniscient_administrator: bool;
}
[@@deriving eq, yojson]

let make ~entry_is_public ~actor_role ~actor_is_omniscient_administrator =
  {entry_is_public; actor_role; actor_is_omniscient_administrator}

let make_of_poly ~entry_is_public ~actor_role ~actor_is_omniscient_administrator =
  make
    ~entry_is_public
    ~actor_role: (Option.map actor_role_of_poly actor_role)
    ~actor_is_omniscient_administrator

type view_reason =
  | Public
  | Viewer
  | Owner
  | Omniscient_administrator
[@@deriving show]

let view_reason {entry_is_public; actor_role; actor_is_omniscient_administrator} =
  match entry_is_public, actor_role, actor_is_omniscient_administrator with
  | true, _, _ -> Public
  | _, Some Owner, _ -> Owner
  | _, Some Viewer, _ -> Viewer
  | _, _, true -> Omniscient_administrator
  | _ -> failwith "Permission.view_reason"

type edit_reason =
  | Owner
  | Omniscient_administrator
[@@deriving show]

let edit_reason {actor_role; actor_is_omniscient_administrator; _} =
  match actor_role, actor_is_omniscient_administrator with
  | Some Owner, _ -> Some Owner
  | _, true -> Some Omniscient_administrator
  | _ -> None

type delete_reason =
  | Owner
  | Omniscient_administrator
[@@deriving show]

let delete_reason {actor_role; actor_is_omniscient_administrator; _} =
  match actor_role, actor_is_omniscient_administrator with
  | Some Owner, _ -> Some Owner
  | _, true -> Some Omniscient_administrator
  | _ -> None

type share_reason =
  | Owner
  | Omniscient_administrator

let share_reason {actor_role; actor_is_omniscient_administrator; _} =
  match actor_role, actor_is_omniscient_administrator with
  | Some Owner, _ -> Some Owner
  | _, true -> Some Omniscient_administrator
  | _ -> None
