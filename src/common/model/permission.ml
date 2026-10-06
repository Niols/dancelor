type role =
  Normal_user | Maintainer | Administrator
[@@deriving eq, yojson]

type actor_role =
  | Owner
  | Viewer
[@@deriving eq, yojson]

type t = {
  entity_is_public: bool;
  actor_role: actor_role option;
  actor_is_omniscient_administrator: bool;
}
[@@deriving eq, yojson]

type view_reason =
  | Public
  | Viewer
  | Owner
  | Omniscient_administrator
[@@deriving show]

let view_reason {entity_is_public; actor_role; actor_is_omniscient_administrator} =
  match entity_is_public, actor_role, actor_is_omniscient_administrator with
  | true, _, _ -> Public
  | _, Some Owner, _ -> Owner
  | _, Some Viewer, _ -> Viewer
  | _, _, true -> Omniscient_administrator
  | _ -> failwith "Permission.view_reason"

(* FIXME: if the entity is public, then maintainers also should be able to edit/delete! *)
type edit_reason =
  | Owner
  | Omniscient_administrator
[@@deriving show]

let edit_reason {actor_role; actor_is_omniscient_administrator; _} =
  match actor_role, actor_is_omniscient_administrator with
  | Some Owner, _ -> Some Owner
  | _, true -> Some Omniscient_administrator
  | _ -> None

type delete_reason = edit_reason
[@@deriving show]

let delete_reason = edit_reason

type share_reason =
  | Owner
  | Omniscient_administrator

let share_reason {actor_role; actor_is_omniscient_administrator; _} =
  match actor_role, actor_is_omniscient_administrator with
  | Some Owner, _ -> Some Owner
  | _, true -> Some Omniscient_administrator
  | _ -> None
