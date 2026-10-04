open Nes
open Dancelor_common

include Shared.Make_public_full(struct
  type entry = Model_builder.Core.Tune.t
  type id = Tune_id.t
  type row = Tune_row.t
  type view = Tune_view.t
  type form = Tune_form.t
  type query = Tune_query.t
  include Database.Tune
end)

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Tune.t -> a = fun env endpoint ->
  match endpoint with
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
