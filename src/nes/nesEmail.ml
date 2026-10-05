type t = string
[@@deriving eq]

let is_email s =
  let has_newline = String.exists (function '\r' | '\n' -> true | _ -> false) s in
  not has_newline && Result.is_ok (Emile.address_of_string_with_crlf (s ^ "\r\n"))

let to_string s = s

let of_string s =
  if is_email s then Some s
  else None

let of_string_exn s =
  match of_string s with Some s -> s | None -> failwith "NesEmail.of_string_exn"

let to_yojson s = `String s

let of_yojson = function
  | `String s ->
    (
      match of_string s with
      | Some s -> Ok s
      | None -> Error "NesEmail.of_yojson: not a valid string"
    )
  | _ -> Error "NesEmail.of_yojson: not a string"
