open Nes
open Model_unix

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
module Group_id_conv = Make_id_conv(Group_tag)

module Kind_conv = struct
  let get_column : string -> Kind.Base.t = function
    | "Air" -> Air
    | "Hornpipe" -> Hornpipe
    | "Jig" -> Jig
    | "Jig_9_8" -> Jig_9_8
    | "March_2_4" -> March_2_4
    | "March_4_4" -> March_4_4
    | "March_6_8" -> March_6_8
    | "Other" -> Other
    | "Polka" -> Polka
    | "Reel" -> Reel
    | "Schottische" -> Schottische
    | "Strathspey" -> Strathspey
    | "Two_step" -> Two_step
    | "Waltz" -> Waltz
    | _ -> failwith "Sql_types.Kind_conv.get_column"
  let get_column_nullable = Option.map get_column
  let set_param : Kind.Base.t -> string = function
    | Air -> "Air"
    | Hornpipe -> "Hornpipe"
    | Jig -> "Jig"
    | Jig_9_8 -> "Jig_9_8"
    | March_2_4 -> "March_2_4"
    | March_4_4 -> "March_4_4"
    | March_6_8 -> "March_6_8"
    | Other -> "Other"
    | Polka -> "Polka"
    | Reel -> "Reel"
    | Schottische -> "Schottische"
    | Strathspey -> "Strathspey"
    | Two_step -> "Two_step"
    | Waltz -> "Waltz"
end

module Two_chords_conv = struct
  let get_column : string -> Dance_view.two_chords = function
    | "Dont_know" -> Dont_know
    | "One_chord" -> One_chord
    | "Two_chords" -> Two_chords
    | _ -> failwith "Sql_types.Two_chords_conv.get_column"
  let get_column_nullable = Option.map get_column
  let set_param : Dance_view.two_chords -> string = function
    | Dont_know -> "Dont_know"
    | One_chord -> "One_chord"
    | Two_chords -> "Two_chords"
end

module Role_conv = struct
  let get_column : string -> Permission.role = function
    | "Normal_user" -> Normal_user
    | "Maintainer" -> Maintainer
    | "Administrator" -> Administrator
    | _ -> failwith "Sql_types.Role_conv.get_column"
  let get_column_nullable = Option.map get_column
  let set_param : Permission.role -> string = function
    | Normal_user -> "Normal_user"
    | Maintainer -> "Maintainer"
    | Administrator -> "Administrator"
end

module Actor_role_conv = struct
  let get_column : string -> Permission.actor_role = function
    | "Owner" -> Owner
    | "Viewer" -> Viewer
    | _ -> failwith "Sql_types.Actor_role_conv.get_column"
  let get_column_nullable = Option.map get_column
  let set_param : Permission.actor_role -> string = function
    | Owner -> "Owner"
    | Viewer -> "Viewer"
end

module Type_conv = struct
  let get_column : string -> Any_id.Type.t = function
    | "Person" -> Person
    | "User" -> User
    | "Dance" -> Dance
    | "Source" -> Source
    | "Tune" -> Tune
    | "Version" -> Version
    | "Set" -> Set
    | "Book" -> Book
    | "Group" -> Group
    | _ -> failwith "Sql_types.Type_conv.get_column"
  let get_column_nullable = Option.map get_column
  let set_param : Any_id.Type.t -> string = function
    | Person -> "Person"
    | User -> "User"
    | Dance -> "Dance"
    | Source -> "Source"
    | Tune -> "Tune"
    | Version -> "Version"
    | Set -> "Set"
    | Book -> "Book"
    | Group -> "Group"
end

module Username_conv = struct
  let get_column : string -> Username.t = Username.of_string_exn
  let get_column_nullable = Option.map get_column
  let set_param : Username.t -> string = Username.to_string
end

module type Fresh_string = sig
  type t
  val inject : string -> t
  val project : t -> string
end

module Make_fresh_string_conv (X : Fresh_string) = struct
  let get_column : string -> X.t = X.inject
  let get_column_nullable = Option.map get_column
  let set_param : X.t -> string = X.project
end

module type Fresh_hashed_secret = sig
  type t
  val inject : Hashed_secret.t -> t
  val project : t -> Hashed_secret.t
end

module Make_fresh_hashed_secret_conv (X : Fresh_hashed_secret) = struct
  let get_column : string -> X.t = X.inject % Hashed_secret.unsafe_of_string
  let get_column_nullable = Option.map get_column
  let set_param : X.t -> string = Hashed_secret.unsafe_to_string % X.project
end

module Password_conv = Make_fresh_hashed_secret_conv(Password_hash)
module Password_reset_token_hash_conv = Make_fresh_hashed_secret_conv(Password_reset_token_hash)
module Remember_me_key_conv = Make_fresh_string_conv(Remember_me_key)
module Remember_me_token_clear_conv = Make_fresh_string_conv(Remember_me_token_clear)
module Remember_me_token_hash_conv = Make_fresh_hashed_secret_conv(Remember_me_token_hash)

module Email_conv = struct
  let get_column : string -> Email.t = Email.of_string_exn
  let get_column_nullable = Option.map get_column
  let set_param : Email.t -> string = Email.to_string
end
