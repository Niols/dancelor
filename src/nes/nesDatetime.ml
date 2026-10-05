open NesPervasives

module I = ISO8601.Permissive

type t = float [@@deriving eq, ord]
(* Number of seconds since 00:00:00 GMT, Jan. 1, 1970.*)

let of_string s =
  try
    Some (I.datetime ~reqtime: true s)
  with
    | _ -> None

let of_string_exn s =
  match of_string s with
  | Some dt -> dt
  | None -> failwith "NesDatetime.of_string_exn"

let to_string = I.string_of_datetime

let pp fmt = fpf fmt "%s" % to_string

let to_yojson date =
  `String (to_string date)

let of_yojson = function
  | `String s ->
    (
      match of_string s with
      | Some dt -> Ok dt
      | None -> Error "NesDatetime.of_yojson: not a valid datetime"
    )
  | _ -> Error "NesDatetime.of_yojson: not a JSON string"

let now = Unix.gettimeofday

let diff = (-.)

let in_the_past t =
  (t -. now ()) < 0.

let make_in_the_past d =
  now () -. d

let make_in_the_future d =
  now () +. d
