open Nes

type alteration =
  Flat | Sharp | Natural
[@@deriving eq, ord, show {with_path = false}, qcheck2]

let alteration_to_string = function Flat -> "b" | Sharp -> "#" | Natural -> ""
let alteration_to_pretty_string = function Flat -> "♭" | Sharp -> "♯" | Natural -> ""
let alteration_to_lilypond_string = function Flat -> "es" | Sharp -> "is" | Natural -> ""

let alteration_of_string = function
  | "b" -> Flat
  | "#" -> Sharp
  | "" -> Natural
  | _ -> failwith "Dancelor_common.Music.alteration_of_string"

type octave = int
[@@deriving eq, ord, show {with_path = false}]

let gen_octave = QCheck2.Gen.int_range (-8) 8

let octave_to_lilypond_string octave =
  if octave < 0 then String.make (-octave) ','
  else String.make octave '\''

let octave_to_string = octave_to_lilypond_string (* FIXME *)

let octave_of_string = function
  | "" -> 0
  | str ->
    let chr = str.[0] in
    if String.exists ((<>) chr) str then
      failwith "Dancelor_common.Music.octave_of_string";
    match chr with
    | '\'' -> String.length str
    | ',' -> -(String.length str)
    | _ -> failwith "Dancelor_common.Music.octave_of_string"

type t = {
  note: Note.t;
  alteration: alteration;
  octave: octave
}
[@@deriving eq, ord, show {with_path = false}, qcheck2]

let make note alteration octave = {note; alteration; octave}

let note pitch = pitch.note
let alteration pitch = pitch.alteration
let octave pitch = pitch.octave

let to_string pitch =
  Note.to_string pitch.note ^
  alteration_to_string pitch.alteration ^
  octave_to_string pitch.octave

let to_pretty_string pitch =
  Note.to_string pitch.note ^
  alteration_to_pretty_string pitch.alteration ^
  octave_to_string pitch.octave

let to_lilypond_string pitch =
  Note.to_lilypond_string pitch.note ^
  alteration_to_lilypond_string pitch.alteration ^
  octave_to_lilypond_string pitch.octave

let of_string = function
  | "" -> failwith "Dancelor_common.Music.Pitch.of_string"
  | s ->
    let note_alteration_str, octave_str =
      (* FIXME: Dirty as fuck *)
      match String.index_opt s ',' with
      | Some i ->
        (String.sub s 0 i, String.sub s i (String.length s - i))
      | None ->
        match String.index_opt s '\'' with
        | Some i ->
          (String.sub s 0 i, String.sub s i (String.length s - i))
        | None ->
          (s, "")
    in
    let note_char = note_alteration_str.[0] in
    let alteration_str = String.sub note_alteration_str 1 (String.length note_alteration_str - 1) in
    {
      note = Note.of_char note_char;
      alteration = alteration_of_string alteration_str;
      octave = octave_of_string octave_str
    }

let to_yojson = Utils.to_yojson__of__to_string to_string
let of_yojson = Utils.of_yojson__of__of_string of_string "Dancelor_common.Music.Pitch.of_yojson"

let to_int pitch =
  (
    match note pitch with
    | C -> 0
    | D -> 2
    | E -> 4
    | F -> 5
    | G -> 7
    | A -> 9
    | B -> 11
  ) +
    (
      match alteration pitch with
      | Flat -> -1
      | Natural -> 0
      | Sharp -> +1
    ) +
    (octave pitch * 12)

let of_int =
  (* Between sharp or flat, we choose the one whose key
     has the least amount of sharps/flats. *)
  let of_int = [|
    make C Natural;
    make C Sharp;
    make D Natural;
    make E Flat;
    make E Natural;
    make F Natural;
    make F Sharp;
    make G Natural;
    make A Flat;
    make A Natural;
    make B Flat;
    make B Natural;
  |]
  in
  fun n ->
    of_int.(pmod n 12) (pdiv n 12)

let%test _ = of_int 0 = make C Natural 0
let%test _ = of_int 1 = make C Sharp 0
let%test _ = of_int 12 = make C Natural 1
let%test _ = of_int 23 = make B Natural 1
let%test _ = of_int (-1) = make B Natural (-1)
let%test _ = of_int (-24) = make C Natural (-2)
let%test _ = of_int (-43) = make F Natural (-4)
let%test "of_int % to_int = id" =
  List.for_all (fun n -> to_int (of_int n) = n) (List.init 50 (fun i -> (i - 25)))

let diff p1 p2 = to_int p1 - to_int p2

let add p1 n = of_int (to_int p1 + n)

include struct
  (* HACK: ppx_inline_test v0.17 expands to an unused `let module M`, which
     OCaml 5.5 flags with warning 60. *)
  [@@@warning "-unused-module"]

  let%test_module _ = (module struct
    let c0 = make C Natural 0

    let%test _ = add c0 0 = c0
    let%test _ = add c0 1 = make C Sharp 0
    let%test _ = add c0 2 = make D Natural 0
    let%test _ = add c0 15 = make E Flat 1
    let%test _ = add c0 (-1) = make B Natural (-1)
    let%test _ = add c0 (-2) = make B Flat (-1)
  end)
end
