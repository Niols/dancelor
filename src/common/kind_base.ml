open Nes

type t =
  | Air
  | Hornpipe
  | Jig
  | Jig_9_8
  | March_2_4
  | March_4_4
  | March_6_8
  | Other
  | Polka
  | Reel
  | Schottische
  | Strathspey
  | Two_step
  | Waltz
[@@deriving eq, ord, show {with_path = false}]

(* NOTE: The order matters as it is used by eg. the tune editor. *)
let all = [
  (* The three main ones *)
  Jig;
  Reel;
  Strathspey;
  (* Fairly popular ones *)
  March_6_8;
  March_4_4;
  Hornpipe;
  Polka;
  Air;
  Schottische;
  Waltz;
  (* More esoteric stuff *)
  March_2_4;
  Two_step;
  Jig_9_8;
  Other;
]

let to_short_string = function
  | Air -> "A"
  | Hornpipe -> "H"
  | Jig -> "J"
  | Jig_9_8 -> "J98"
  | March_2_4 -> "M24"
  | March_4_4 -> "M44"
  | March_6_8 -> "M68"
  | Other -> "O"
  | Polka -> "P"
  | Reel -> "R"
  | Strathspey -> "S"
  | Schottische -> "Sch"
  | Two_step -> "TS"
  | Waltz -> "W"

let to_long_string ~capitalised base =
  (if capitalised then String.capitalize_ascii else Fun.id)
    (
      match base with
      | Air -> "air"
      | Hornpipe -> "hornpipe"
      | Jig -> "jig"
      | Jig_9_8 -> "jig[9/8]"
      | March_2_4 -> "march[2/4]"
      | March_4_4 -> "march[4/4]"
      | March_6_8 -> "march[6/8]"
      | Other -> "other"
      | Polka -> "polka"
      | Reel -> "reel"
      | Strathspey -> "strathspey"
      | Schottische -> "schottische"
      | Two_step -> "two-step"
      | Waltz -> "waltz"
    )

let of_string s =
  match String.lowercase_ascii s with
  | "a" | "air" -> Air
  | "h" | "hornpipe" -> Hornpipe
  | "j" | "jig" -> Jig
  | "j98" | "jig[9/8]" -> Jig_9_8
  | "m24" | "march[2/4]" -> March_2_4
  | "m44" | "march[4/4]" -> March_4_4
  | "m68" | "march[6/8]" -> March_6_8
  | "o" | "other" -> Other
  | "p" | "polka" -> Polka
  | "r" | "reel" -> Reel
  | "s" | "strathspey" -> Strathspey
  | "sch" | "schottische" -> Schottische
  | "ts" | "two-step" -> Two_step
  | "w" | "waltz" -> Waltz
  | _ -> invalid_arg "Dancelor_common.Kind.Base.of_string"

let of_string_opt s =
  try
    Some (of_string s)
  with
    | Invalid_argument _ -> None

let to_yojson b =
  `String (to_long_string ~capitalised: false b)

let of_yojson = function
  | `String s ->
    (
      try
        Ok (of_string s)
      with
        | _ -> Error "Dancelor_common.Kind.Base.of_yojson: not a valid base kind"
    )
  | _ -> Error "Dancelor_common.Kind.Base.of_yojson: not a JSON string"

let tempo = function
  | Air -> ("2", 60)
  | Hornpipe -> ("2", 108)
  | Jig -> ("4.", 104)
  | Jig_9_8 -> ("4.", 104)
  | March_2_4 -> ("2", 108)
  | March_4_4 -> ("2", 108)
  | March_6_8 -> ("4.", 104)
  | Other -> ("2", 108)
  | Polka -> ("2", 108)
  | Reel -> ("2", 108)
  | Strathspey -> ("2", 60)
  | Schottische -> ("2", 60)
  | Two_step -> ("4", 130)
  | Waltz -> ("2.", 60)
