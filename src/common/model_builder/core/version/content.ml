open Nes

type destructured = {
  parts: Voices.t NEList.t;
  transitions: (Part_name.opens * Part_name.opens * Voices.t) list;
  default_structure: Structure.t;
  as_2_4: bool; (* only used for binary kinds *)
}
[@@deriving eq, ord, yojson, show {with_path = false}]

type t =
  | No_content
  | Destructured of destructured
  | Monolithic of {lilypond: string; bars: int; structure: Structure.t}
[@@deriving eq, ord, yojson, show {with_path = false}, variants]

let erase_lilypond = function
  | No_content -> No_content
  | Destructured {default_structure; _} ->
    Destructured {
      default_structure;
      as_2_4 = false;
      parts = NEList.singleton Voices.empty;
      transitions = [];
    }
  | Monolithic {bars; structure; _} -> Monolithic {bars; structure; lilypond = ""}

(** Auxiliary function to {!lilypond}, doing the heavy lifting. Given a list of
    [~parts], an association list of [~transitions], and an already folded
    [~structure], generate LilyPond, under the form of a {!Voices.t}.
    [~show_part_marks] decides whether some boxes with the part numbers should
    be shown when printing a part. *)
let lilypond_voices
    ~(parts : Voices.t list)
    ~(transitions : (Part_name.opens * Part_name.opens * Voices.t) list)
    ~(structure : Structure.folded)
    ~(show_part_marks : bool)
  =
  let transition ~toplevel from to_ =
    (* NOTE: The transition from start and to the end should only ever be
       considered when at toplevel of the structure; otherwise they would be
       produced at all levels of imbricated repeats. *)
    if (from = Part_name.Start || to_ = Part_name.End) && not toplevel then Voices.empty
    else
      Option.value
        (
          List.find_map
            (fun (from_l, to_l, voices) ->
              if NEList.mem from from_l && NEList.mem to_ to_l then Some voices
              else None
            )
            transitions
        )
        ~default: Voices.empty
  in
  let rec item_to_lilypond ~toplevel ~next_part = function
    | Structure.Part part ->
      (
        let lilypond = List.nth parts (Part_name.to_int part) in
        let lilypond = if show_part_marks then Voices.concat (Voices.mark part) lilypond else lilypond in
        Voices.concat_l [lilypond; Voices.space; transition ~toplevel (Middle part) next_part]
      )
    | Repeat (times, structure) ->
      (
        let lilypond : Voices.t = to_lilypond ~toplevel: false structure in
        let first_part = Structure.first_part_exn structure in
        let last_part = Structure.last_part_exn structure in
        let alt_1 = transition ~toplevel (Middle last_part) (Middle first_part) in
        let alt_2 = transition ~toplevel (Middle last_part) next_part in
        if Voices.equal alt_1 alt_2 then
          {
            Voices.melody = spf "\\repeat volta %d { %s %s }" times lilypond.melody alt_1.melody;
            Voices.chords = spf "%s %s" lilypond.chords alt_1.chords;
          }
        else if Voices.equal alt_1 Voices.empty then
          {
            Voices.melody = spf "\\repeat volta %d { %s } %s" times lilypond.melody alt_2.melody;
            Voices.chords = spf "%s %s" lilypond.chords alt_2.chords;
          }
        else
          {
            Voices.melody = spf "\\repeat volta %d { %s } \\alternative { { %s } { %s } }" times lilypond.melody alt_1.melody alt_2.melody;
            Voices.chords = spf "%s %s %s" lilypond.chords alt_1.chords alt_2.chords;
          }
      )
  and map_item_to_lilypond ~toplevel = function
    | [] -> []
    | item :: items ->
      let next_part =
        Option.fold
          ~none: Part_name.End
          ~some: Part_name.middle
          (Structure.first_part items)
      in
      item_to_lilypond ~toplevel ~next_part item :: map_item_to_lilypond ~toplevel items
  and to_lilypond ~toplevel structure =
    Voices.concat_l (List.intersperse Voices.section_break (map_item_to_lilypond ~toplevel structure))
  in
  let lilypond = to_lilypond ~toplevel: true structure in
  let first_part = Structure.first_part_exn structure in
  Voices.concat_l [transition ~toplevel: true Start (Middle first_part); Voices.space; lilypond]

let lilypond ?structure ~as_2_4 ~kind ~key parts transitions =
  let Voices.{melody; chords} =
    (* Wrap the parts in \relative f' by default. If the parts come with their
       own \relative, it will override our own, so the change won't be impactful. *)
    let parts = List.map Voices.relative_f' @@ NEList.to_list parts in
    let transitions = List.map (fun (from, to_, voices) -> (from, to_, Voices.relative_f' voices)) transitions in
    let structure, show_part_marks =
      (* If we are asked for a structure, and we can find a best fold for it,
         then we produce that folded structure and do not show part marks.
         Otherwise, we print all parts in order, and we do show part marks. *)
      Option.fold
        (Option.bind structure Structure.best_fold_for)
        ~some: (fun structure -> (structure, false))
        ~none: (List.mapi (fun n _ -> Structure.part @@ Part_name.of_int n) parts, true)
    in
    Voices.concat (lilypond_voices ~parts ~transitions ~structure ~show_part_marks) Voices.fine
  in
  let time =
    match (kind : Kind.Base.t) with
    | Jig | March_6_8 -> "6/8"
    | Reel | Hornpipe | Polka | March_2_4 | March_4_4 ->
      if as_2_4 then "2/4" else "4/4" (* technically 2/2 but https://github.com/niols/dancelor/issues/744 *)
    | Strathspey | Air | Schottische -> "4/4"
    | Jig_9_8 -> "9/8"
    | Two_step -> "4/4"
    | Waltz -> "3/4"
    | Other -> "2/2" (* FIXME: we should not let Other be used for destructured tunes *)
  in let key =
    (Music.Pitch.to_lilypond_string @@ Music.Key.pitch key) ^
    " " ^ (Music.Mode.to_lilypond_string @@ Music.Key.mode key)
  in
  spf
    "<< \\new Voice {\\clef treble \\time %s \\key %s {%s}}\\new ChordNames {\\chordmode {%s}}>>"
    time
    key
    melody
    chords

let lilypond ?structure ~kind ~key = function
  | No_content -> None
  | Monolithic {lilypond; _} -> Some lilypond
  | Destructured {parts; transitions; as_2_4; _} -> Some (lilypond ?structure ~as_2_4 ~kind ~key parts transitions)
