open Nes
open Sqlgg_trait_types

module Log = (val Logs.src_log @@ Logs.Src.create "server.database.sqlgg-postgresql": Logs.LOG)

exception Oops of string

(* ---- Core types ---- *)

type pg_conn = {
  conn: Postgresql.connection;
  fd: Lwt_unix.file_descr;
}

type 'a connection = pg_conn

type statement = {
  sql: string;
  connection: pg_conn;
}

type row = Postgresql.result * int

type result = Postgresql.result

type params = {
  stmt: statement;
  values: string array;
  mutable pos: int;
}

type execute_response = {
  affected_rows: int64;
  insert_id: int64 option;
}

(* ---- IO ---- *)

module IO = struct
  type 'a future = 'a Lwt.t
  let return = Lwt.return
  let (>>=) = Lwt.bind
  let bracket x fin f =
    Lwt.bind x (fun x -> Lwt.finalize (fun () -> f x) (fun () -> fin x))
end

(* ---- Helpers ---- *)

let check (r : Postgresql.result) =
  match r#status with
  | Postgresql.Tuples_ok | Postgresql.Command_ok -> ()
  | _ -> raise (Oops r#error)

let get_col (r, i) col = r#getvalue i col
let is_null (r, i) col = r#getisnull i col
let nullable f row col = if is_null row col then None else Some (f row col)

let set_param p s =
  p.values.(p.pos) <- s;
  p.pos <- p.pos + 1

(* ---- Async query execution ---- *)

let async_exec {conn; fd} ?params sql =
  Log.debug (fun m -> m "Executing: %s" sql);
  (
    match params with
    | Some params -> conn#send_query ~params sql
    | None -> conn#send_query sql
  );
  let rec flush () =
    match conn#flush with
    | Postgresql.Successful -> Lwt.return_unit
    | Postgresql.Data_left_to_send ->
      Lwt_unix.wait_write fd >>= fun () ->
      flush ()
  in
  let rec poll () =
    Lwt_unix.wait_read fd >>= fun () ->
    conn#consume_input;
    if conn#is_busy then poll ()
    else
      match conn#get_result with
      | None -> raise (Oops "async_exec: no result")
      | Some r ->
        (* Drain any remaining results *)
        ignore (conn#get_result);
        check r;
        Lwt.return r
  in
  flush () >>= fun () ->
  poll ()

(* ---- Types ---- *)

module Types = struct
  module Bool = struct
    type t = bool
    let to_literal b = if b then "true" else "false"
    let bool_to_literal = to_literal
  end
  module Int = struct
    type t = int64
    let to_literal = Int64.to_string
    let int64_to_literal = to_literal
  end
  module UInt64 = struct
    type t = Unsigned.UInt64.t
    let to_literal = Unsigned.UInt64.to_string
    let uint64_to_literal = to_literal
  end
  module Float = struct
    type t = float
    let to_literal = string_of_float
    let float_to_literal = to_literal
  end
  module Text = struct
    type t = string
    let to_literal s =
      "'" ^ String.concat "''" (String.split_on_char '\'' s) ^ "'"
    let string_to_literal = to_literal
  end
  module Blob = struct
    type t = string
    let to_literal = Text.to_literal
    let string_to_literal = to_literal
  end
  module Decimal = struct
    type t = float
    let to_literal = string_of_float
    let float_to_literal = to_literal
  end
  module Datetime = struct
    type t = Datetime.t
    let to_literal dt = "'" ^ Datetime.to_string dt ^ "'"
    let float_to_literal f = "'" ^ string_of_float f ^ "'"
  end
  module Json = struct
    type t = json
    let to_literal j = "'" ^ Yojson.Safe.to_string (j :> Yojson.Safe.t) ^ "'"
    let json_to_literal = to_literal
  end
  module Json_path = struct
    type t = json_path
    let to_literal _ = failwith "Json_path.to_literal: not implemented"
    let json_path_to_literal = to_literal
  end
  module One_or_all = struct
    type t = one_or_all
    let to_literal = function `One -> "'one'" | `All -> "'all'"
  end
  module Any = struct
    type t = string
    let to_literal s = s
  end
end

type num = Types.Int.t
type text = Types.Text.t
type any = Types.Any.t
type datetime = Types.Datetime.t

(* ---- Column accessors (lowercase / raw) ---- *)

let get_column_bool row col =
  match get_col row col with
  | "t" | "true" | "1" -> true
  | _ -> false
let get_column_bool_nullable row col = nullable get_column_bool row col

let get_column_int64 row col = Int64.of_string (get_col row col)
let get_column_int64_nullable row col = nullable get_column_int64 row col

let get_column_uint64 row col = Unsigned.UInt64.of_string (get_col row col)
let get_column_uint64_nullable row col = nullable get_column_uint64 row col

let get_column_float row col = float_of_string (get_col row col)
let get_column_float_nullable row col = nullable get_column_float row col

let get_column_decimal row col = float_of_string (get_col row col)
let get_column_decimal_nullable row col = nullable get_column_decimal row col

let get_column_datetime row col = get_col row col
let get_column_datetime_nullable row col = nullable get_column_datetime row col

let get_column_string row col = get_col row col
let get_column_string_nullable row col = nullable get_column_string row col

let get_column_json row col =
  get_col row col |> Yojson.Safe.from_string |> convert_json
let get_column_json_nullable row col = nullable get_column_json row col

let get_column_json_path _row _col =
  failwith "get_column_json_path: not implemented"
let get_column_json_path_nullable row col =
  nullable get_column_json_path row col

let get_column_one_or_all row col =
  match get_col row col with
  | "one" -> `One
  | "all" -> `All
  | s -> raise (Oops ("get_column_one_or_all: unexpected value: " ^ s))
let get_column_one_or_all_nullable row col =
  nullable get_column_one_or_all row col

(* ---- Column accessors (capitalised / typed) ---- *)

let get_column_Bool = get_column_bool
let get_column_Bool_nullable = get_column_bool_nullable
let get_column_Int = get_column_int64
let get_column_Int_nullable = get_column_int64_nullable
let get_column_UInt64 = get_column_uint64
let get_column_UInt64_nullable = get_column_uint64_nullable
let get_column_Float = get_column_float
let get_column_Float_nullable = get_column_float_nullable
let get_column_Text = get_column_string
let get_column_Text_nullable = get_column_string_nullable
let get_column_Any = get_column_string
let get_column_Any_nullable = get_column_string_nullable
let get_column_Decimal = get_column_decimal
let get_column_Decimal_nullable = get_column_decimal_nullable
let get_column_Datetime row col = Datetime.of_string_exn (get_col row col)
let get_column_Datetime_nullable row col = nullable get_column_Datetime row col
let get_column_Json = get_column_json
let get_column_Json_nullable = get_column_json_nullable
let get_column_Json_path = get_column_json_path
let get_column_Json_path_nullable = get_column_json_path_nullable
let get_column_One_or_all = get_column_one_or_all
let get_column_One_or_all_nullable = get_column_one_or_all_nullable

(* ---- Param setters (lowercase / raw) ---- *)

let set_param_bool p b = set_param p (if b then "true" else "false")
let set_param_int64 p i = set_param p (Int64.to_string i)
let set_param_uint64 p u = set_param p (Unsigned.UInt64.to_string u)
let set_param_float p f = set_param p (string_of_float f)
let set_param_decimal p f = set_param p (string_of_float f)
let set_param_string p s = set_param p s
let set_param_datetime p f = set_param p (string_of_float f)
let set_param_json p j =
  set_param p (Yojson.Safe.to_string (j :> Yojson.Safe.t))
let set_param_json_path _p _j =
  failwith "set_param_json_path: not implemented"
let set_param_one_or_all p = function
  | `One -> set_param p "one"
  | `All -> set_param p "all"

(* ---- Param setters (capitalised / typed) ---- *)

let set_param_null p = set_param p Postgresql.null
let set_param_Text = set_param_string
let set_param_Any = set_param_string
let set_param_Bool = set_param_bool
let set_param_Int = set_param_int64
let set_param_UInt64 = set_param_uint64
let set_param_Float = set_param_float
let set_param_Decimal = set_param_decimal
let set_param_Datetime p dt = set_param p (Datetime.to_string dt)
let set_param_Json = set_param_json
let set_param_Json_path = set_param_json_path
let set_param_One_or_all = set_param_one_or_all

(* ---- Enums ---- *)

module Make_enum (E : Sqlgg_traits.Enum) = struct
  let get_column row col = E.inj (get_col row col)
  let get_column_nullable row col = nullable get_column row col
  let set_param p v = set_param p (E.proj v)
  let to_literal v = "'" ^ E.proj v ^ "'"
end

(* ---- Query execution ---- *)

let start_params stmt n =
  {stmt; values = Array.make n Postgresql.null; pos = 0}

let finish_params p =
  async_exec p.stmt.connection ~params: p.values p.stmt.sql

let no_params stmt =
  async_exec stmt.connection stmt.sql

let select conn (q : Sqlgg_traits.Query.t) f callback =
  f {sql = q.sql; connection = conn} >>= fun r ->
  for i = 0 to r#ntuples - 1 do callback (r, i) done;
  Lwt.return_unit

let select_one_maybe conn (q : Sqlgg_traits.Query.t) f callback =
  f {sql = q.sql; connection = conn} >>= fun r ->
  if r#ntuples = 0 then Lwt.return_none
  else Lwt.return_some (callback (r, 0))

let select_one conn q f callback =
  select_one_maybe conn q f callback >>= function
    | Some x -> Lwt.return x
    | None -> raise (Oops "select_one: no rows returned")

let execute conn (q : Sqlgg_traits.Query.t) f =
  f {sql = q.sql; connection = conn} >>= fun r ->
  let affected_rows =
    match r#cmd_tuples with
    | "" -> 0L
    | s -> Int64.of_string s
  in
  Lwt.return {affected_rows; insert_id = None}

let execute_unprepared conn (q : Sqlgg_traits.Query.t) =
  execute conn q no_params
