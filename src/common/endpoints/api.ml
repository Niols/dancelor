open Nes
open Madge

module Endpoints = struct
  type (_, _, _) t =
  (* resources *)
  | Source : ('a, 'w, 'r) Source.t -> ('a, 'w, 'r) t
  | Person : ('a, 'w, 'r) Person.t -> ('a, 'w, 'r) t
  | Book : ('a, 'w, 'r) Book.t -> ('a, 'w, 'r) t
  | Version : ('a, 'w, 'r) Version.t -> ('a, 'w, 'r) t
  | Dance : ('a, 'w, 'r) Dance.t -> ('a, 'w, 'r) t
  | Set : ('a, 'w, 'r) Set.t -> ('a, 'w, 'r) t
  | Tune : ('a, 'w, 'r) Tune.t -> ('a, 'w, 'r) t
  (* principals *)
  | User : ('a, 'w, 'r) User.t -> ('a, 'w, 'r) t
  | Group : ('a, 'w, 'r) Group.t -> ('a, 'w, 'r) t
  (* others *)
  | Entity : ('a, 'w, 'r) Entity.t -> ('a, 'w, 'r) t
  | Job : ('a, 'w, 'r) Job.t -> ('a, 'w, 'r) t
  | Report_issue : (Issue_report.request -> 'w, 'w, Issue_report.response) t
  [@@deriving madge_wrapped_endpoints]
end
include Endpoints

include Madge.Make_endpoints(struct
  include Endpoints

  let route_internal : type a w r. (a, w, r) t -> (a, w, r) route =
    let open Route in
    function
      | Source endpoint -> literal "source" @@ Source.route endpoint
      | Person endpoint -> literal "person" @@ Person.route endpoint
      | Book endpoint -> literal "book" @@ Book.route endpoint
      | Version endpoint -> literal "version" @@ Version.route endpoint
      | Dance endpoint -> literal "dance" @@ Dance.route endpoint
      | Set endpoint -> literal "set" @@ Set.route endpoint
      | Tune endpoint -> literal "tune" @@ Tune.route endpoint
      | Entity endpoint -> literal "entity" @@ Entity.route endpoint
      | User endpoint -> literal "user" @@ User.route endpoint
      | Group endpoint -> literal "group" @@ Group.route endpoint
      | Job endpoint -> literal "job" @@ Job.route endpoint
      | Report_issue -> literal "issue" @@ literal "report" @@ query_json "request" (module Issue_report.Request) @@ post (module Issue_report.Response)
end)

let href : type a r. (a, Uri.t, r) t -> a = fun endpoint ->
  with_request (route endpoint) @@ fun (module _) request ->
  assert (Request.meth request = GET);
  Request.uri request
