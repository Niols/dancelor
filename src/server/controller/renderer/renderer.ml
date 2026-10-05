(** {1 Renderer} *)

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.renderer": Logs.LOG)

open Nes_unix

(** {2 Models for the rendering} *)

type tune = {
  slug: string;
  name: string;
  instructions: string;
  composer: string;
  content: string;
  first_bar: int;
  tempo_unit: string;
  tempo_value: int;
  chords_kind: string;
  show_bar_numbers: bool;
  show_time_signatures: bool;
}
[@@deriving yojson]

type part = {
  name: string;
}
[@@deriving yojson]

type set = {
  slug: string;
  name: string;
  conceptor: string;
  kind: string;
  contents: tune list;
}
[@@deriving yojson]

type page =
  | Part of part
  | Set of set
[@@deriving variants]

let page_to_yojson = function
  | Part part -> `Assoc [("part", part_to_yojson part)]
  | Set set -> `Assoc [("set", set_to_yojson set)]

let page_of_yojson = function
  | `Assoc [("part", json)] -> Result.map part @@ part_of_yojson json
  | `Assoc [("set", json)] -> Result.map set @@ set_of_yojson json
  | _ -> Error "page_of_yojson"

type book = {
  slug: string;
  name: string;
  editor: string;
  contents: page list;
  simple: bool; (* FIXME: should that not go into {!book_pdf_arg} *)
}
[@@deriving yojson]

(** {2 Nix integration} *)
(* TODO: This would probably be much faster if we used Nix as a library. *)

let escape_double_quotes string =
  let buf = Buffer.create (String.length string) in
  Buffer.add_char buf '"';
  String.iter
    (function
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | c -> Buffer.add_char buf c
    )
    string;
  Buffer.add_char buf '"';
  Buffer.contents buf

type call_nix_config = {
  share: string;
  nixpkgs: string;
}

let call_nix fun_ json =
  let%lwt store_path =
    (* NOTE: We could use the temporary file directly, instead of adding it to
       the store, but (1) it would make it harder to inspect the command after
       the fact since the input file would have disappeared, and (2) this way we
       make the [call_nix] function deterministic, and therefore we can use its
       resulting expression and cache it. *)
    Lwt_io.with_temp_file @@ fun (fname, ochan) ->
    Lwt_io.write ochan (Yojson.Safe.to_string json);%lwt
    Lwt_process.pread ("", [|"nix"; "--extra-experimental-features"; "nix-command"; "store"; "add"; "--name"; "renderer-input.json"; "--mode"; "flat"; fname|])
  in
  let expr =
    spf
      "(import %s/renderer/renderer.nix { %s}).%s (builtins.fromJSON (builtins.readFile %s))"
      (if ((Config.get ()).share).[0] = '/' then (Config.get ()).share else "./" ^ (Config.get ()).share)
      (if (Config.get ()).nixpkgs = "" then "" else "nixpkgs = " ^ escape_double_quotes (Config.get ()).nixpkgs ^ "; ")
      fun_
      store_path
  in
  Log.debug (fun m -> m "call_nix: %s" expr);
  lwt @@ Job.Expr expr

(** {2 API} *)

let make_tune_snippets = call_nix "makeTuneSnippets" % tune_to_yojson
let make_tune_svg tune = Pair.snoc "snippet.svg" <$> make_tune_snippets tune
let make_tune_ogg tune = Pair.snoc "snippet.ogg" <$> make_tune_snippets tune

type pdf_metadata = {
  title: string;
  authors: string list;
  subjects: string list;
}
[@@deriving yojson]

type set_pdf_arg = {
  set: set;
  specificity: string;
  headers: bool;
  pdf_metadata: pdf_metadata;
}
[@@deriving yojson]

let make_set_pdf arg =
  Pair.snoc "set.pdf" <$> call_nix "makeSetPdf" (set_pdf_arg_to_yojson arg)

type book_pdf_arg = {
  book: book;
  specificity: string;
  headers: bool;
  pdf_metadata: pdf_metadata;
}
[@@deriving yojson]

let make_book_pdf arg =
  Pair.snoc "book.pdf" <$> call_nix "makeBookPdf" (book_pdf_arg_to_yojson arg)

type sets_zip_arg_set = {
  set: set;
  pdf_metadata: pdf_metadata;
}
[@@deriving yojson]

type sets_zip_arg = {
  sets: sets_zip_arg_set NEList.t;
  specificity: string;
  headers: bool;
}
[@@deriving yojson]

let make_sets_zip arg =
  Pair.snoc "sets.zip" <$> call_nix "makeSetsZip" (sets_zip_arg_to_yojson arg)
