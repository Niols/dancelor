open NesPervasives

module I = ISO8601.Permissive

type t = float [@@deriving eq, ord]
(* Number of seconds since 00:00:00 GMT, Jan. 1, 1970.*)

let to_timestamp = Fun.id

let of_timestamp = Fun.id

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

type duration = float [@@deriving eq, ord]
(* Number of seconds between two events. *)

let forever = Float.infinity

let duration_to_seconds = Fun.id

let duration_of_seconds = Fun.id
let duration_of_seconds' s = duration_of_seconds (float_of_int s)

let duration_of_minutes = ( *. ) 60.
let duration_of_minutes' d = duration_of_minutes (float_of_int d)

let duration_of_hours = ( *. ) 3600.
let duration_of_hours' d = duration_of_hours (float_of_int d)

let duration_of_days = ( *. ) 86400.
let duration_of_days' d = duration_of_days (float_of_int d)

(** ISO 8601 inspired components, but with representation of all the seconds and
    stopping at days precision. *)
type duration_components = {
  days: int;
  hours: int;
  minutes: int;
  seconds: float;
}

let extract_duration_components df =
  let d = int_of_float df in
  let (d, seconds) = (d / 60, Float.rem df 60.) in
  let (d, minutes) = (d / 60, d mod 60) in
  let (days, hours) = (d / 24, d mod 24) in
    {days; hours; minutes; seconds}

let combine_duration_components {days; hours; minutes; seconds} =
  float_of_int (86400 * days + 3600 * hours + 60 * minutes) +. seconds

let duration_to_string d =
  let {days; hours; minutes; seconds} = extract_duration_components d in
  spf "P%dDT%dH%dM%fS" days hours minutes seconds

let duration_of_string s =
  try
    Some (
      Scanf.sscanf s "P%dDT%dH%dM%fS" @@ fun days hours minutes seconds ->
      combine_duration_components {days; hours; minutes; seconds}
    )
  with
    | Scanf.Scan_failure _ -> None

let duration_to_yojson date =
  `String (duration_to_string date)

let duration_of_yojson = function
  | `String s ->
    (
      match duration_of_string s with
      | Some d -> Ok d
      | None -> Error "NesDatetime.duration_of_yojson: not a valid duration"
    )
  | _ -> Error "NesDatetime.duration_of_yojson: not a JSON string"

let duration_of_string_exn s =
  match duration_of_string s with
  | Some d -> d
  | None -> failwith "NesDatetime.duration_of_string_exn"

let pp_duration_pretty fmt d =
  if d < 60. then
    (
      if d = 1. then
        fpf fmt "1 second"
      else
        fpf fmt "%.3g seconds" d
    )
  else
    let {days; hours; minutes; seconds} = extract_duration_components d in
    (match days with 0 -> () | 1 -> fpf fmt "1 day" | n -> fpf fmt "%d days" n);
    (if days <> 0 && hours <> 0 then fpf fmt " ");
    (match hours with 0 -> () | 1 -> fpf fmt "1 hour" | n -> fpf fmt "%d hours" n);
    (if (days <> 0 || hours <> 0) && minutes <> 0 then fpf fmt " ");
    (match minutes with 0 -> () | 1 -> fpf fmt "1 minute" | n -> fpf fmt "%d minutes" n);
    (if (days <> 0 || hours <> 0 || minutes <> 0) && seconds <> 0. then fpf fmt " ");
    (if seconds = 0. then () else if seconds = 1. then fpf fmt "1 second" else fpf fmt "%.0f seconds" seconds)

let duration_to_string_pretty d =
  aspf "%a" pp_duration_pretty d

let%test _ = duration_to_string_pretty 0. = "0 seconds"
let%test _ = duration_to_string_pretty 63.5 = "1 minute 4 seconds"
let%test _ = duration_to_string_pretty 320437.54 = "3 days 17 hours 38 seconds"

let mult = ( *. )

let diff = (-.)

let duration_to_now d = diff (now ()) d

let in_the_past t =
  (t -. now ()) < 0.

let make_in_the_past d =
  now () -. d

let make_in_the_future d =
  now () +. d
