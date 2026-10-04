open Nes

type 'value t = string

let rem_to_char rem =
  if rem < 10 then
    Char.chr (Char.code '0' + rem)
  else if rem < 36 then
    Char.chr (Char.code 'a' + rem - 10)
  else
    failwith "rem_to_char: out of range"

let rem_of_char c =
  if Char.code c >= Char.code '0' && Char.code c <= Char.code '9' then
    Char.code c - Char.code '0'
  else if Char.code c >= Char.code 'a' && Char.code c <= Char.code 'z' then
    Char.code c - Char.code 'a' + 10
  else
    failwith "rem_of_char: out of range"

let check str =
  String.length str = 14
  && str.[4] = '-'
  && str.[9] = '-'
  && (
    let sum = ref 0 in
    let process_one_char i = sum := !sum + rem_of_char str.[i] in
    for i = 0 to 3 do process_one_char i done;
    for i = 5 to 8 do process_one_char i done;
    for i = 10 to 13 do process_one_char i done;
    (!sum mod 36) = 0
  )

let%test _ = check "iq57-aju6-cj4o"

let make () =
  let str = Bytes.create 14 in
  Bytes.set str 4 '-';
  Bytes.set str 9 '-';
  let sum = ref 0 in
  let process_one_char i =
    let n = Random.int 36 in
    sum := !sum + n;
    Bytes.set str i (rem_to_char n)
  in
  for i = 1 to 3 do process_one_char i done;
  (* mind the [1] *)
  for i = 5 to 8 do process_one_char i done;
  for i = 10 to 13 do process_one_char i done;
  Bytes.set str 0 (rem_to_char ((36 - (!sum mod 36)) mod 36));
  let str = Bytes.unsafe_to_string str in
  assert (check str);
  str

let%test _ = try ignore (List.init 100 (fun _ -> make ())); true with Assert_failure _ -> false

let to_string = Fun.id

let to_yojson' s = `String s
let to_yojson _ = to_yojson'

let pp' fmt id = Format.fprintf fmt "%s" id
let pp _ = pp'

let of_string str = if check str then Some str else None

let of_string_exn str =
  match of_string str with
  | Some str -> str
  | None -> invalid_arg @@ spf "not a valid id: `%s`" str

let of_yojson' = function
  | `String s -> Option.to_result ~none: (spf "not a valid id: `%s`" s) (of_string s)
  | _ -> Error "not a string"
let of_yojson _ = of_yojson'

let unsafe_coerce = Fun.id

let equal' = (=)
let equal _ = equal'

let unsafe_equal = (=)

let compare' = Stdlib.compare
let compare _ = compare'

(* Madge serialisation: we can serialise and unserialise as strings no matter
   what the type is, so we only need a type from. *)

module type TYPEABLE = sig type t end

module S (A : TYPEABLE) : Madge.STRINGABLE with type t = A.t t = struct
  type nonrec t = A.t t
  let to_string = to_string
  let of_string = of_string
end

module J (A : TYPEABLE) : Madge.JSONABLE with type t = A.t t = struct
  type nonrec t = A.t t
  let to_yojson = to_yojson'
  let of_yojson = of_yojson'
end
