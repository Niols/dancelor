(* Extensions to existing modules. *)

include NesPervasives
module Char = NesChar
module Filename = NesFilename
module Format = NesFormat
module Int = NesInt
module Int64 = NesInt64
module List = NesList
module Lwt = NesLwt
module Lwt_list = NesLwt_list
module Lwt_stream = NesLwt_stream
module Seq = NesSeq
module String = NesString
module Option = NesOption
module Result = NesResult
module Fun = NesFun

(* Extensions to existing non-Stdlib modules *)

module Uri = NesUri

(* New modules *)

module Cache = NesCache
module Datetime = NesDatetime
module Depart = NesDepart
module Email = NesEmail
module PartialDate = NesPartialDate
module Slice = NesSlice
module Json = NesJson
module Void = NesVoid
module Password = NesPassword
module HashedSecret = NesHashedSecret
module NEList = NesNEList
module NEString = NesNEString
module Pair = NesPair
module Fresh = NesFresh
module Username = NesUsername

(* Monads *)

module Olwt = NesOlwt
module Rlwt = NesRlwt
