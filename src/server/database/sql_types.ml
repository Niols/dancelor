open Dancelor_common

module Make_id_conv (T : sig type t end) = struct
  let get_column : string -> T.t Entry.Id.t = Entry.Id.of_string_exn
  let get_column_nullable : string option -> T.t Entry.Id.t option = Option.map Entry.Id.of_string_exn
  let set_param : T.t Entry.Id.t -> string = Entry.Id.to_string
end

module Entry_id_conv = struct
  let get_column : string -> 'any Entry.Id.t = Entry.Id.of_string_exn
  let get_column_nullable : string option -> 'any Entry.Id.t option = fun x -> Option.map Entry.Id.of_string_exn x
  let set_param : 'any Entry.Id.t -> string = Entry.Id.to_string
end

module Person_id_conv = Make_id_conv(Model_builder.Core.Person)
module Dance_id_conv = Make_id_conv(Model_builder.Core.Dance)
module Source_id_conv = Make_id_conv(Model_builder.Core.Source)
module Tune_id_conv = Make_id_conv(Model_builder.Core.Tune)
module Version_id_conv = Make_id_conv(Model_builder.Core.Version)
module Set_id_conv = Make_id_conv(Model_builder.Core.Set)
module Book_id_conv = Make_id_conv(Model_builder.Core.Book)
module User_id_conv = Make_id_conv(Model_builder.Core.User)

type kind_base = [
  | `Air
  | `Hornpipe
  | `Jig
  | `Jig_9_8
  | `March_2_4
  | `March_4_4
  | `March_6_8
  | `Other
  | `Polka
  | `Reel
  | `Schottische
  | `Strathspey
  | `Two_step
  | `Waltz
]

let kind_base_to_common : kind_base -> Kind_base.t = function
  | `Air -> Air
  | `Hornpipe -> Hornpipe
  | `Jig -> Jig
  | `Jig_9_8 -> Jig_9_8
  | `March_2_4 -> March_2_4
  | `March_4_4 -> March_4_4
  | `March_6_8 -> March_6_8
  | `Other -> Other
  | `Polka -> Polka
  | `Reel -> Reel
  | `Schottische -> Schottische
  | `Strathspey -> Strathspey
  | `Two_step -> Two_step
  | `Waltz -> Waltz

let kind_base_of_common : Kind_base.t -> kind_base = function
  | Air -> `Air
  | Hornpipe -> `Hornpipe
  | Jig -> `Jig
  | Jig_9_8 -> `Jig_9_8
  | March_2_4 -> `March_2_4
  | March_4_4 -> `March_4_4
  | March_6_8 -> `March_6_8
  | Other -> `Other
  | Polka -> `Polka
  | Reel -> `Reel
  | Schottische -> `Schottische
  | Strathspey -> `Strathspey
  | Two_step -> `Two_step
  | Waltz -> `Waltz

type two_chords = [`Dont_know | `One_chord | `Two_chords]

let two_chords_to_common : two_chords -> Model_builder.Core.Dance.two_chords = function
  | `Dont_know -> Dont_know
  | `One_chord -> One_chord
  | `Two_chords -> Two_chords

let two_chords_of_common : Model_builder.Core.Dance.two_chords -> two_chords = function
  | Dont_know -> `Dont_know
  | One_chord -> `One_chord
  | Two_chords -> `Two_chords
