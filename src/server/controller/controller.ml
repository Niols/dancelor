open Nes
open Dancelor_common

module Source = Source
module Person = Person
module Set = Set
module Book = Book
module Dance = Dance
module Version = Version
module Tune = Tune
module Entity = Entity
module Job = Job
module Metrics = Metrics

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller": Logs.LOG)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Api.t -> a = fun env endpoint ->
  match endpoint with
  | Source endpoint -> Source.dispatch env endpoint
  | Person endpoint -> Person.dispatch env endpoint
  | Book endpoint -> Book.dispatch env endpoint
  | Version endpoint -> Version.dispatch env endpoint
  | Dance endpoint -> Dance.dispatch env endpoint
  | Set endpoint -> Set.dispatch env endpoint
  | Tune endpoint -> Tune.dispatch env endpoint
  | User endpoint -> User.dispatch env endpoint
  | Group endpoint -> Group.dispatch env endpoint
  | Entity endpoint -> Entity.dispatch env endpoint
  | Job endpoint -> Job.dispatch env endpoint
  | Report_issue -> Issue_report.report env
