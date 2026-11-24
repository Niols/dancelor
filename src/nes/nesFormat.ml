include Format

let pp_to_show pp x =
  let buf = Buffer.create 128 in
  let fmt = Format.formatter_of_buffer buf in
  pp_set_margin fmt (1 lsl 28);
  pp_set_max_indent fmt (1 lsl 24);
  fprintf fmt "%a@?" pp x;
  Buffer.contents buf

let pp_multiline_sensible name fmt s =
  let rec remove_empty_first_lines = function
    | [] -> []
    | "" :: lines -> remove_empty_first_lines lines
    | lines -> lines
  in
  let rec remove_empty_last_lines = function
    | [] -> []
    | "" :: lines ->
      (
        match remove_empty_last_lines lines with
        | [] -> []
        | lines -> "" :: lines
      )
    | line :: lines ->
      line :: remove_empty_last_lines lines
  in
  s
  |> String.split_on_char '\n'
  |> remove_empty_first_lines
  |> remove_empty_last_lines
  |> (function [] -> ["(empty)"] | s -> s)
  |> (function
      | [] -> assert false
      | [line] -> Format.fprintf fmt "%s: %s" name line
      | lines ->
        Format.fprintf fmt "%s:" name;
        List.iter (Format.fprintf fmt "@\n%s") lines
    )
