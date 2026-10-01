open NesUnix
open Dancelor_common
open Model_new
open Search_new

include Shared.Make_public_full(struct
  type entry = Model_builder.Core.Dance.t
  type id = Dance_id.t
  type row = Dance_row.t
  type view = Dance_view.t
  type form = Dance_form.t
  type query = Dance_query.t
  include Database.Dance
end)

(* Legacy *)

let get env id =
  match%lwt Database.Dance.get id with
  | None -> Permission.reject_can_get ()
  | Some dance ->
    Permission.assert_can_get_public env dance;%lwt
    lwt dance

let tunes env id =
  let%lwt _ = get env id in
  let%lwt tunes = Database.Tune.get_rows_for_dance id in
  let%lwt tunes = Lwt_list.filter_s (Permission.can_get_public_new env) tunes in
  lwt tunes

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Dance.t -> a = fun env endpoint ->
  match endpoint with
  | Get -> get env
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
  | Tunes -> tunes env
