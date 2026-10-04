open Nes

module Book_parameters = Book_parameters
module Permission_new = Permission_new
module Set_order = Set_order
module Set_parameters = Set_parameters
module Version_content = Version_content
module Version_parameters = Version_parameters

include Base
include Tags
include Ids
include Names
include Rows
include Views
include Forms

(** Special case of the actor, which is the connected user, used by the client
    to show various things. *)
module Actor = struct
  type t = {
    id: User_id.t;
    username: Username.t;
    github_handle: string option; (* FIXME: probably only the server cares? *)
    role: Permission_new.role;
    omniscience: bool;
    person: Person_row.t option;
  }
  [@@deriving eq, fields, yojson]

  let to_user_row {id; username; _} : User_row.t =
    {id; username}
end
