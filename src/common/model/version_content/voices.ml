open Nes

type t = {
  melody: string;
  chords: string;
}
[@@deriving eq, ord, yojson, show {with_path = false}, fields]

let empty = {melody = ""; chords = ""}
let space = {melody = " "; chords = " "}
let mark c = {melody = spf "\\mark\\markup\\box{%c} " (Part_name.to_char c); chords = ""}
let section_break = {melody = " \\section\\break "; chords = " "}
let fine = {melody = " \\fine"; chords = ""}

let relative_f' {melody; chords} = {melody = spf "\\relative f' { %s }" melody; chords}

let concat v1 v2 = {melody = v1.melody ^ v2.melody; chords = v1.chords ^ v2.chords}
let concat_l = List.fold_left concat empty
