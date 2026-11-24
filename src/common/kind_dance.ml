open Nes

include Kind_dance_type

let rec pp ppf = function
  | Version version_kind -> fpf ppf "%s" (Kind_version.to_string version_kind)
  | Add (kind1, kind2) -> fpf ppf "%a + %a" pp kind1 pp kind2
  | Mul (n, kind) ->
    (match kind with Add _ -> fpf ppf "%d x (%a)" | _ -> fpf ppf "%d x %a")
      n
      pp
      kind

let to_string = Format.pp_to_show pp

let of_string_opt s =
  try
    Some (Kind_dance_parser.main Kind_dance_lexer.token (Lexing.from_string s))
  with
    | Kind_dance_parser.Error | Kind_dance_lexer.Unexpected_character _ -> None

let of_string s =
  match of_string_opt s with Some k -> k | None -> failwith "Kind.Dance.of_string"

let%test _ = to_string (Mul (3, Version (32, Strathspey))) = "3 x 32 S"
let%test _ = to_string (Version (128, Jig)) = "128 J"
let%test _ = to_string (Mul (2, Add (Version (32, Strathspey), Version (24, Reel)))) = "2 x (32 S + 24 R)"
let%test _ = to_string (Add (Version (32, Strathspey), Add (Mul (7, Add (Version (12, Jig), Version (24, Reel))), Version (888, Strathspey)))) = "32 S + 7 x (12 J + 24 R) + 888 S"

let%test _ = of_string "3 x ( 32 Strathspey )" = Mul (3, Version (32, Strathspey))
let%test _ = of_string "(32W + 64R)" = Add (Version (32, Waltz), Version (64, Reel))
let%test _ = of_string "3x40J" = Mul (3, Version (40, Jig))
let%test _ = of_string "32R" = Version (32, Reel)
let%test _ = of_string_opt "R" = None

let to_yojson d =
  `String (to_string d)

let of_yojson = function
  | `String s ->
    (
      try
        Ok (of_string s)
      with
        | _ -> Error "Dancelor_common.Model.Kind.of_yojson: not a valid dance kind"
    )
  | _ -> Error "Dancelor_common.Model.Kind.of_yojson: not a JSON string"

let rec to_pretty_string = function
  | Version vkind -> Kind_version.to_pretty_string vkind
  | Add (kind1, kind2) -> spf "%s + %s" (to_pretty_string kind1) (to_pretty_string kind2)
  | Mul (n, kind) ->
    (match kind with Add _ -> spf "%d x (%s)" | _ -> spf "%d x %s")
      n
      (to_pretty_string kind)

let rec to_simple = function
  | Version (bars, base) -> Some (1, bars, base)
  | Add (kind1, kind2) ->
    Option.bind (to_simple kind1) @@ fun (n1, bars1, base1) ->
    Option.bind (to_simple kind2) @@ fun (n2, bars2, base2) ->
    if base1 = base2 then
      if bars1 = bars2 then
        Some (n1 + n2, bars1, base1)
      else
        Some (1, n1 * bars1 + n2 * bars2, base1)
    else
      None
  | Mul (n, kind) ->
    Option.map (fun (n', bars, base) -> (n * n', bars, base)) (to_simple kind)
