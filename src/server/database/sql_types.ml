open Dancelor_common

module Make_id_conv (Tag : sig type t end) = struct
  let get_column : string -> Tag.t Id.t = Id.of_string_exn
  let get_column_nullable : string option -> Tag.t Id.t option = Option.map Id.of_string_exn
  let set_param : Tag.t Id.t -> string = Id.to_string
end

module Untagged_id_conv = Make_id_conv(Untagged)
module Person_id_conv = Make_id_conv(Person_tag)
module Dance_id_conv = Make_id_conv(Dance_tag)
module Source_id_conv = Make_id_conv(Source_tag)
module Tune_id_conv = Make_id_conv(Tune_tag)
module Version_id_conv = Make_id_conv(Version_tag)
module Set_id_conv = Make_id_conv(Set_tag)
module Book_id_conv = Make_id_conv(Book_tag)
module User_id_conv = Make_id_conv(User_tag)

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

let kind_base_to_common : kind_base -> Kind.Base.t = function
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

let kind_base_of_common : Kind.Base.t -> kind_base = function
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

let two_chords_to_common : two_chords -> Dance_view.two_chords = function
  | `Dont_know -> Dont_know
  | `One_chord -> One_chord
  | `Two_chords -> Two_chords

let two_chords_of_common : Dance_view.two_chords -> two_chords = function
  | Dont_know -> `Dont_know
  | One_chord -> `One_chord
  | Two_chords -> `Two_chords

type role = [`Normal_user | `Maintainer | `Administrator]

let role_to_common : role -> Permission_new.role = function
  | `Normal_user -> Normal_user
  | `Maintainer -> Maintainer
  | `Administrator -> Administrator

let role_of_common : Permission_new.role -> role = function
  | Normal_user -> `Normal_user
  | Maintainer -> `Maintainer
  | Administrator -> `Administrator

type actor_role = [`Owner | `Viewer]

let actor_role_to_common : actor_role -> Permission_new.actor_role = function
  | `Owner -> Owner
  | `Viewer -> Viewer

let actor_role_of_common : Permission_new.actor_role -> actor_role = function
  | Owner -> `Owner
  | Viewer -> `Viewer

type type_ = [`Person | `User | `Dance | `Source | `Tune | `Version | `Set | `Book]

let type_to_common : type_ -> Any_id.Type.t = function
  | `Person -> Person
  | `User -> User
  | `Dance -> Dance
  | `Source -> Source
  | `Tune -> Tune
  | `Version -> Version
  | `Set -> Set
  | `Book -> Book

let type_of_common : Any_id.Type.t -> type_ = function
  | Person -> `Person
  | User -> `User
  | Dance -> `Dance
  | Source -> `Source
  | Tune -> `Tune
  | Version -> `Version
  | Set -> `Set
  | Book -> `Book
