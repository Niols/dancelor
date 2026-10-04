open Nes

type t = int (* number of semitones *)
[@@deriving eq, ord, show {with_path = false}, yojson]

let identity = 0
let compose = (+)

let to_semitones = id

let from_semitones = id
let from_octaves = ( * ) 12

let target_pitch ~source t = Pitch.add source t
