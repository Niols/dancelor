module Entity = Entity
module Book = Book
module Dance = Dance
module Person = Person
module Set = Set
module Source = Source
module Tune = Tune
module User = User
module Group = Group
module Version = Version
module Utils = Utils

type t = Connection.t
let with_ = Connection.with_

module Migrations = Migrations
let apply_migrations = Migrations.apply_migrations
