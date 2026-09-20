open Nes

let log_src = Logs.Src.create "common.logger"
module Log = (val Logs.src_log log_src: Logs.LOG)

type loglevel = [%import: Logs.level]
[@@deriving show {with_path = false}]

let loglevel_to_string = function
  | Logs.Error -> "error"
  | Warning -> "warning"
  | Info -> "info"
  | Debug -> "debug"
  | App -> assert false

let loglevel_to_yojson level = `String (loglevel_to_string level)

let loglevel_of_string = function
  | "error" -> Ok Logs.Error
  | "warning" -> Ok Warning
  | "info" -> Ok Info
  | "debug" -> Ok Debug
  | str -> Error (spf "Invalid log level: %s" str)

let loglevel_of_yojson = function
  | `String json -> loglevel_of_string json
  | _ -> Error "Expected a JSON string for log level"

type loglevel_map = {
  cases: (string * loglevel option) list;
  default: loglevel option;
}
[@@deriving show {with_path = false}, yojson]

let matches_loglevel_pattern ~pattern name =
  let pattern = String.split_on_char '.' pattern in
  let name = String.split_on_char '.' name in
  let rec matches pattern name =
    match pattern, name with
    | [], [] -> true
    | ["*"], _ -> true
    | "*" :: _, _ -> invalid_arg "matches_loglevel_pattern: invalid pattern"
    | p :: ps, n :: ns when p = n -> matches ps ns
    | _ -> false
  in
  matches pattern name

let find_level loglevel_map name =
  match List.find_opt (fun (pattern, _) -> matches_loglevel_pattern ~pattern name) loglevel_map.cases with
  | Some (_, level) -> level
  | None -> loglevel_map.default

(** Vertical separation of logical units in the logs (eg. level | source |
    message). *)
let vsep = " │ "

let setup_reporter reporter =
  (* Wrap the given reporter to add the source at the beginning of each line. *)
  let report src level ~over k msgf =
    reporter.Logs.report src level ~over k @@ fun m ->
    msgf @@ fun ?header ?tags fmt ->
    m ?header ?tags ("%s%s" ^^ fmt) (Logs.Src.name src) vsep
  in
  Logs.set_reporter {report}

let initialise loglevel =
  (
    match loglevel.default with
    | None -> ()
    | Some default_loglevel ->
      match default_loglevel with
      | Logs.Error | Warning ->
        Log.info (fun m -> m "Default log level will be %a from now on; this is the last Info message." pp_loglevel default_loglevel);
      | Info | Debug -> ()
      | App -> assert false
  );
  (* Crawl through all defined sources, but handle the one for this module
     before all others, since it itself logs debug messages. *)
  List.iter
    (fun src ->
      let name = Logs.Src.name src in
      let level = find_level loglevel name in
      Logs.Src.set_level src level;
      Log.debug (fun m -> m "Set %S to %S" name (Logs.level_to_string level))
    )
    (log_src :: Logs.Src.list ());
  (* Initialise future loglevels to the default. *)
  Logs.set_level ~all: false loglevel.default

let early_loglevel = {cases = []; default = Some Info}

(** Early initialisation. This has to be called before anything else, so that
    even if early things break, we get some logging. *)
let early_initialisation ~reporter =
  Log.debug (fun m -> m "Starting early initialisation of logging...");
  setup_reporter reporter;
  initialise early_loglevel;
  Log.info (fun m -> m "Early initialisation of logging done")

(** Late initialisation. This is meant to be called after eg. configuration has
    been loaded, to set up the right log levels. *)
let late_initialisation loglevel =
  Log.debug (fun m -> m "Starting late initialisation of logging...");
  initialise loglevel;
  Log.info (fun m -> m "Late initialisation of logging done")

(** Full initialisation, for when it doesn't make sense to separate between
    early and late phases, eg. on the JS client. *)
let full_initialisation ~reporter loglevel =
  Log.debug (fun m -> m "Starting full initialisation of logging...");
  setup_reporter reporter;
  initialise loglevel;
  Log.info (fun m -> m "Full initialisation of logging done")

let bracket (module Log : Logs.LOG) msg f =
  Log.debug (fun m -> m "%s" (String.capitalize_ascii msg));
  let v = f () in
  Log.info (fun m -> m "Done %s" msg);
  v

let bracket_lwt (module Log : Logs.LOG) msg f =
  Log.debug (fun m -> m "%s" (String.capitalize_ascii msg));
  let%lwt v = f () in
  Log.info (fun m -> m "Done %s" msg);
  lwt v
