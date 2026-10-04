open Nes

type t = int (* invariant: ∈ [0; 25] *)
[@@deriving eq, ord, show {with_path = false}]

let to_int = id
let of_int = id

let of_char c =
  let c = Char.code c in
  if c < 65 || c > 90 then None else Some (c - 65)

let of_char_exn c =
  match of_char c with
  | Some c -> c
  | None -> failwith "Version.Content.Part_name.of_char_exn: not a letter between A and Z"

let of_string s = if String.length s = 1 then of_char s.[0] else None

let to_char p = Char.chr (p + 65)

let to_string p = String.make 1 (to_char p)

type open_ =
  Start | Middle of t | End
[@@deriving eq, ord, show {with_path = false}, variants]

let open_to_string = function
  | Start -> "start"
  | End -> "end"
  | Middle p -> to_string p

let open_of_string = function
  | "start" -> Some Start
  | "end" -> Some End
  | s -> Option.map middle (of_string s)

let open__to_yojson p = `String (open_to_string p)

let open__of_yojson = function
  | `String s -> Option.to_result ~none: "opens__of_yojson" (open_of_string s)
  | _ -> Error ""

type opens = open_ NEList.t
[@@deriving eq, ord, show {with_path = false}]

let opens_to_string = String.concat ", " % List.map open_to_string % NEList.to_list

let opens_of_string =
  Option.join % Option.map NEList.of_list %
    Monadise.Option.lift_1_1 List.map (open_of_string % String.trim) %
    String.split_on_char ','

let opens_to_yojson p = `String (opens_to_string p)

let opens_of_yojson = function
  | `String s -> Option.to_result ~none: "opens_of_yojson" (opens_of_string s)
  | _ -> Error ""
