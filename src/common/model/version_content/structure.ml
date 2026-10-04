open Nes

type t = Part_name.t NEList.t
[@@deriving eq, ord, show {with_path = false}]

let to_string = NEString.of_string_exn % String.of_seq % Seq.map Part_name.to_char % List.to_seq % NEList.to_list
let of_string = Option.join % Option.map NEList.of_list % Monadise.Option.lift_1_1 List.map Part_name.of_char % List.of_seq % String.to_seq % NEString.to_string

let to_yojson s = `String (NEString.to_string @@ to_string s)
let of_yojson = function
  | `String s -> Option.to_result ~none: "not a valid structure" (Option.bind (NEString.of_string s) of_string)
  | _ -> Error "not a string"

type folded_item = Part of Part_name.t | Repeat of int * folded
and folded = folded_item list

(** A few helpers *)
let a = Part (Part_name.of_char_exn 'A')
let b = Part (Part_name.of_char_exn 'B')
let c = Part (Part_name.of_char_exn 'C')
let d = Part (Part_name.of_char_exn 'D')
let e = Part (Part_name.of_char_exn 'E')
let f = Part (Part_name.of_char_exn 'F')
let g = Part (Part_name.of_char_exn 'G')
let h = Part (Part_name.of_char_exn 'H')

let part n = Part n
let repeat n x = Repeat (n, x)

let rec first_part_exn structure =
  match List.hd_opt structure with
  | None -> failwith "first_part_exn"
  | Some Part a -> a
  | Some Repeat (_, structure) -> first_part_exn structure

let first_part structure =
  match List.hd_opt structure with
  | None -> None
  | Some Part a -> Some a
  | Some Repeat (_, structure) -> Some (first_part_exn structure)

let rec last_part_exn structure =
  match List.ft_opt structure with
  | None -> failwith "last_part_exn"
  | Some Part a -> a
  | Some Repeat (_, structure) -> last_part_exn structure

let last_part structure =
  match List.ft_opt structure with
  | None -> None
  | Some Part a -> Some a
  | Some Repeat (_, structure) -> Some (last_part_exn structure)

(** A general algorithm would be great, but for now this will do. *)
let best_fold_for structure =
  match NEString.to_string @@ to_string structure with
  | "A" -> some [a]
  | "B" -> some [b]
  | "C" -> some [c]
  | "D" -> some [d]
  | "AA" -> some [repeat 2 [a]]
  | "AB" -> some [a; b]
  | "BA" -> some [b; a]
  | "BB" -> some [repeat 2 [b]]
  | "AAA" -> some [repeat 3 [a]]
  | "AAB" -> some [repeat 2 [a]; b]
  | "ABA" -> some [a; b; a]
  | "ABB" -> some [a; repeat 2 [b]]
  | "BAA" -> some [b; repeat 2 [a]]
  | "BAB" -> some [b; a; b]
  | "BBA" -> some [repeat 2 [b]; a]
  | "BBB" -> some [repeat 3 [b]]
  | "ABC" -> some [a; b; c]
  | "AAAA" -> some [repeat 4 [a]]
  | "AAAB" -> some [repeat 3 [a]; b]
  | "AABA" -> some [repeat 2 [a]; b; a]
  | "AABB" -> some [repeat 2 [a]; repeat 2 [b]]
  | "ABAA" -> some [a; b; repeat 2 [a]]
  | "ABAB" -> some [repeat 2 [a; b]]
  | "ABBA" -> some [a; repeat 2 [b]; a]
  | "ABBB" -> some [a; repeat 3 [b]]
  | "BAAA" -> some [b; repeat 3 [a]]
  | "BAAB" -> some [b; repeat 2 [a]; b]
  | "BABA" -> some [repeat 2 [b; a]]
  | "BABB" -> some [b; a; repeat 2 [b]]
  | "BBAA" -> some [repeat 2 [b]; repeat 2 [a]]
  | "BBAB" -> some [repeat 2 [b]; a; b]
  | "BBBA" -> some [repeat 3 [b]; a]
  | "BBBB" -> some [repeat 4 [b]]
  | "AABC" -> some [repeat 2 [a]; b; c]
  | "ABBC" -> some [a; repeat 2 [b]; c]
  | "ABCC" -> some [a; b; repeat 2 [c]]
  | "ABCA" -> some [a; b; c; a]
  | "ABCB" -> some [a; b; c; b]
  | "ABCD" -> some [a; b; c; d]
  | "ABAC" -> some [a; b; a; c]
  | "AABBB" -> some [repeat 2 [a]; repeat 3 [b]]
  | "AABBC" -> some [repeat 2 [a]; repeat 2 [b]; c]
  | "AABCC" -> some [repeat 2 [a]; b; repeat 2 [c]]
  | "ABABA" -> some [repeat 2 [a; b]; a]
  | "ABABB" -> some [repeat 2 [a; b]; b]
  | "ABBAB" -> some [a; repeat 2 [b]; a; b]
  | "ABBCC" -> some [a; repeat 2 [b]; repeat 2 [c]]
  | "ABABC" -> some [repeat 2 [a; b]; c]
  | "ABCDE" -> some [a; b; c; d; e]
  | "ABCBC" -> some [a; repeat 2 [b; c]]
  | "AAAAAA" -> some [repeat 6 [a]]
  | "AAAAAB" -> some [repeat 5 [a]; b]
  | "AAAABB" -> some [repeat 4 [a]; repeat 2 [b]]
  | "AAABBB" -> some [repeat 3 [a]; repeat 3 [b]]
  | "AABBBB" -> some [repeat 2 [a]; repeat 4 [b]]
  | "ABBBBB" -> some [a; repeat 5 [b]]
  | "BBBBBB" -> some [repeat 6 [b]]
  | "ABABAB" -> some [repeat 3 [a; b]]
  | "AABBAB" -> some [repeat 2 [a]; repeat 2 [b]; a; b]
  | "AABBCC" -> some [repeat 2 [a]; repeat 2 [b]; repeat 2 [c]]
  | "AABCBC" -> some [repeat 2 [a]; repeat 2 [b; c]]
  | "ABCABC" -> some [repeat 2 [a; b; c]]
  | "ABCDEF" -> some [a; b; c; d; e; f]
  | "AABAAB" -> some [repeat 2 [repeat 2 [a]; b]]
  | "ABBABB" -> some [repeat 2 [a; repeat 2 [b]]]
  | "ABBACC" -> some [a; repeat 2 [b]; a; repeat 2 [c]]
  | "ABBCBB" -> some [a; repeat 2 [b]; c; repeat 2 [b]]
  | "ABBCDD" -> some [a; repeat 2 [b]; c; repeat 2 [d]]
  | "ABCBAB" -> some [a; b; c; b; a; b]
  | "ABCDCD" -> some [a; b; repeat 2 [c; d]]
  | "ABBAAB" -> some [a; repeat 2 [b]; repeat 2 [a]; b]
  | "AABCAA" -> some [repeat 2 [a]; b; c; repeat 2 [a]]
  | "AABBCCDD" -> some [repeat 2 [a]; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]]
  | "AABBAACC" -> some [repeat 2 [a]; repeat 2 [b]; repeat 2 [a]; repeat 2 [c]]
  | "AABBCCDE" -> some [repeat 2 [a]; repeat 2 [b]; repeat 2 [c]; d; e]
  | "AABBCDEE" -> some [repeat 2 [a]; repeat 2 [b]; c; d; repeat 2 [e]]
  | "AABBCDEF" -> some [repeat 2 [a]; repeat 2 [b]; c; d; e; f]
  | "AABCDDEE" -> some [repeat 2 [a]; b; c; repeat 2 [d]; repeat 2 [e]]
  | "AABCDDEF" -> some [repeat 2 [a]; b; c; repeat 2 [d]; e; f]
  | "AABCDEFF" -> some [repeat 2 [a]; b; c; d; e; repeat 2 [f]]
  | "AABCDEFG" -> some [repeat 2 [a]; b; c; d; e; f; g]
  | "ABCCDDEE" -> some [a; b; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]]
  | "ABCCDDEF" -> some [a; b; repeat 2 [c]; repeat 2 [d]; e; f]
  | "ABCCDEFF" -> some [a; b; repeat 2 [c]; d; e; repeat 2 [f]]
  | "ABCCDEFG" -> some [a; b; repeat 2 [c]; d; e; f; g]
  | "ABCDEEFF" -> some [a; b; c; d; repeat 2 [e]; repeat 2 [f]]
  | "ABCDEEFG" -> some [a; b; c; d; repeat 2 [e]; f; g]
  | "ABCDEFGG" -> some [a; b; c; d; e; f; repeat 2 [g]]
  | "ABCDEFGH" -> some [a; b; c; d; e; f; g; h]
  | "ABBCCDD" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]]
  | "ABBCCDDE" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; e]
  | "ABBCCDDEE" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]]
  | "ABBCCDDEEF" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]; f]
  | "ABBCCDDEEFF" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]; repeat 2 [f]]
  | "ABBCCDDEEFFG" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]; repeat 2 [f]; g]
  | "ABBCCDDEEFFGG" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]; repeat 2 [f]; repeat 2 [g]]
  | "ABBCCDDEEFFGGH" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]; repeat 2 [f]; repeat 2 [g]; h]
  | "ABBCCDDEEFFGGHH" -> some [a; repeat 2 [b]; repeat 2 [c]; repeat 2 [d]; repeat 2 [e]; repeat 2 [f]; repeat 2 [g]; repeat 2 [h]]
  | _ -> None
