open Names

type role =
  Normal_user | Maintainer | Administrator
[@@deriving eq, yojson, show {with_path = false}]

type actor_role =
  | Owner
  | Viewer
[@@deriving eq, yojson, show {with_path = false}]

type actor_group =
  | Direct
  | Via_group of Group_name.t
[@@deriving eq, yojson, show {with_path = false}]

type t = {
  entity_is_public: bool; [@default false]
  actor_role: (actor_role * actor_group) option; [@default None]
  actor_is_omniscient_administrator: bool; [@default false]
}
[@@deriving eq, yojson, show {with_path = false}]

type view_reason =
  | Public
  | Viewer of actor_group
  | Owner of actor_group
  | Omniscient_administrator
[@@deriving show {with_path = false}]

let view_reason {entity_is_public; actor_role; actor_is_omniscient_administrator} =
  match entity_is_public, actor_role, actor_is_omniscient_administrator with
  | true, _, _ -> Public
  | _, Some (Owner, group), _ -> Owner group
  | _, Some (Viewer, group), _ -> Viewer group
  | _, _, true -> Omniscient_administrator
  | _ -> failwith "Permission.view_reason"

(* FIXME: if the entity is public, then maintainers also should be able to edit/delete! *)
type edit_reason =
  | Owner of actor_group
  | Omniscient_administrator
[@@deriving show {with_path = false}]

let edit_reason {actor_role; actor_is_omniscient_administrator; _} =
  match actor_role, actor_is_omniscient_administrator with
  | Some (Owner, group), _ -> Some (Owner group)
  | _, true -> Some Omniscient_administrator
  | _ -> None

type delete_reason = edit_reason
[@@deriving show {with_path = false}]

let delete_reason = edit_reason

type share_reason = edit_reason
[@@deriving show {with_path = false}]

let share_reason = edit_reason
