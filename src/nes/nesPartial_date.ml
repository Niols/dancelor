open NesPervasives

type t =
  | YearMonthDay of int * int * int
  | YearMonth of int * int
  | Year of int
[@@deriving eq, show {with_path = false}]

let check_month month = month >= 1 && month <= 12
let check_full_date ~year ~month ~day =
  try
    ignore (Dates_calc.Dates.make_date ~year ~month ~day);
    true
  with
    | Dates_calc.Dates.InvalidDate -> false

let check = function
  | YearMonthDay (year, month, day) -> check_full_date ~year ~month ~day
  | YearMonth (_year, month) -> check_month month
  | Year _year -> true

let from_string s =
  let date =
    match String.split_on_char '-' s |> List.map int_of_string_opt with
    | [Some year] -> Some (Year year)
    | [Some year; Some month] -> Some (YearMonth (year, month))
    | [Some year; Some month; Some day] -> Some (YearMonthDay (year, month, day))
    | _ -> None
  in
  match date with
  | Some date when check date -> Some date
  | _ -> None

let to_string = function
  | Year year -> spf "%04d" year
  | YearMonth (year, month) -> spf "%04d-%02d" year month
  | YearMonthDay (year, month, day) -> spf "%04d-%02d-%02d" year month day

let compare d1 d2 = String.compare (to_string d1) (to_string d2)

let to_yojson date =
  `String (to_string date)

let of_yojson = function
  | `String s -> Option.to_result ~none: "NesPartialDate.of_yojson: not a valid date" @@ from_string s
  | _ -> Error "NesPartialDate.of_yojson: not a JSON string"

let month_to_pretty_string ?(short = false) month =
  (
    if short then
        [|"Jan"; "Feb"; "Mar"; "Apr"; "May"; "Jun"; "Jul"; "Aug"; "Sep"; "Oct"; "Nov"; "Dec"|]
    else
        [|"January"; "February"; "March"; "April"; "May"; "June"; "July"; "August"; "September"; "October"; "November"; "December"|]
  ).(month - 1)

let to_pretty_string ?(at = false) ?short = function
  | Year year -> spf "%s%d" (if at then "in " else "") year
  | YearMonth (year, month) -> spf "%s%s %d" (if at then "in " else "") (month_to_pretty_string ?short month) year
  | YearMonthDay (year, month, day) -> spf "%s%d %s %d" (if at then "on " else "") day (month_to_pretty_string ?short month) year

(** {2 Helpers to Implement {!NesDate}}

    {!NesDate} can be seen as an instance of this one. It just needs this two
    functions to get it done. *)
