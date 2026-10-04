open Dancelor_common

val get_row_for : actor_id: User_id.t option -> Set_id.t list -> (Set_id.t -> Set_row.t option) Lwt.t
val get_view : actor_id: User_id.t option -> Set_id.t -> Set_view.t option Lwt.t
val get_form : actor_id: User_id.t option -> Set_id.t -> Set_form.t option Lwt.t
val search : actor_id: User_id.t option -> Set_query.t -> (Set_row.t * float) list Lwt.t

val create : Connection.t -> owner_id: User_id.t -> Set_form.t -> Set_id.t Lwt.t
val update : Connection.t -> Set_id.t -> Set_form.t -> unit Lwt.t
val delete : Connection.t -> Set_id.t -> unit Lwt.t
