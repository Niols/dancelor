open NesPervasives

(* INVARIANT: Month and day are counting from 1 *)
type t =
  | Year_month_day of int * int * int
  | Year_month of int * int
  | Year of int
[@@deriving eq, show {with_path = false}]

let year = function
  | Year y | Year_month (y, _) | Year_month_day (y, _, _) -> y

let month1 = function
  | Year _ -> None
  | Year_month (_, m) | Year_month_day (_, m, _) -> Some m

let month0 = Option.map (fun m -> m - 1) % month1

let day1 = function
  | Year _ | Year_month _ -> None
  | Year_month_day (_, _, d) -> Some d

let day0 = Option.map (fun m -> m - 1) % day1

let check = function
  | Year _year -> true
  | Year_month (_year, month) ->
    month >= 1 && month <= 12
  | Year_month_day (year, month, day) ->
    (
      try
        ignore (Dates_calc.Dates.make_date ~year ~month ~day); true
      with
        | Dates_calc.Dates.InvalidDate -> false
    )

let make ~year ?month0 ?month1 ?day0 ?day1 () =
  let month =
    match month0, month1 with
    | Some month0, None -> Some (month0 + 1)
    | None, Some month1 -> Some month1
    | None, None -> None
    | Some _, Some _ -> invalid_arg "NesPartial_date.make"
  in
  let day =
    match day0, day1 with
    | Some day0, None -> Some (day0 + 1)
    | None, Some day1 -> Some day1
    | None, None -> None
    | Some _, Some _ -> invalid_arg "NesPartial_date.make"
  in
  let d =
    match month, day with
    | None, None -> Year year
    | Some month, None -> Year_month (year, month)
    | Some month, Some day -> Year_month_day (year, month, day)
    | None, Some _ -> invalid_arg "NesPartial_date.make"
  in
  if not (check d) then invalid_arg "NesPartial_date.make";
  d

let from_string s =
  let date =
    match String.split_on_char '-' s |> List.map int_of_string_opt with
    | [Some year] -> Some (Year year)
    | [Some year; Some month] -> Some (Year_month (year, month))
    | [Some year; Some month; Some day] -> Some (Year_month_day (year, month, day))
    | _ -> None
  in
  match date with
  | Some date when check date -> Some date
  | _ -> None

let to_string = function
  | Year year -> spf "%04d" year
  | Year_month (year, month) -> spf "%04d-%02d" year month
  | Year_month_day (year, month, day) -> spf "%04d-%02d-%02d" year month day

let compare d1 d2 = String.compare (to_string d1) (to_string d2)

let to_yojson date =
  `String (to_string date)

let of_yojson = function
  | `String s -> Option.to_result ~none: "NesPartial_date.of_yojson: not a valid date" @@ from_string s
  | _ -> Error "NesPartial_date.of_yojson: not a JSON string"

let month_to_pretty_string ?(short = false) month =
  (
    if short then
        [|"Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec"|]
    else
        [|"January"; "February"; "March"; "April"; "May"; "June"; "July"; "August"; "September"; "October"; "November"; "December"|]
  ).(month - 1)

let to_pretty_string ?(at = false) ?short = function
  | Year year -> spf "%s%d" (if at then "in " else "") year
  | Year_month (year, month) -> spf "%s%s %d" (if at then "in " else "") (month_to_pretty_string ?short month) year
  | Year_month_day (year, month, day) -> spf "%s%d %s %d" (if at then "on " else "") day (month_to_pretty_string ?short month) year

let of_unix_tm {Unix.tm_year; tm_mon; tm_mday; _} =
  make ~year: (tm_year + 1900) ~month0: tm_mon ~day0: tm_mday ()

let of_timestamp f =
  of_unix_tm (Unix.gmtime f)

let strip_day = function
  | Year_month_day (y, m, _d) -> Year_month (y, m)
  | d -> d

let strip_month d = Year (year d)
