open Cohttp_lwt_unix

open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server": Logs.LOG)

let log_exn ~msg exn =
  Log.err @@ fun m ->
  m "%a" (Format.pp_multiline_sensible msg) (Printexc.to_string exn ^ "\n" ^ (Printexc.get_backtrace ()))

include Madge_server.Make_apply_controller(struct
  include Endpoints.Api
  type env = Environment.t
  let dispatch = Controller.dispatch
end)

(** Wraps a function into a double catchall: regular exceptions and Lwt
    exceptions. Exceptions are logged as uncaught, and then the `die` function
    is called. *)
let catchall ~place ~die fun_ =
  try
    try%lwt
      fun_ ()
    with
      | Database.Migrations.Migration_failed (name, _exn) ->
        Log.err (fun m -> m "Migration %S failed" name);
        die ()
      | exn ->
        log_exn ~msg: ("Uncaught Lwt exception in " ^ place) exn;
        die ()
  with
    | exn ->
      log_exn ~msg: ("Uncaught exception in " ^ place) exn;
      die ()

(** Callback handling one client request. It is in charge of trying to find what
    will answer to the request: a static file, or a Madge API point, or the
    standard main JS file. *)
let callback _ request body =
  Metrics.increment_http_requests_total ();
  catchall
    ~place: "the callback"
    ~die: Madge_server.respond_internal_server_error
    @@ fun () ->
    match Madge.Request.cohttp_code_meth_to_meth @@ Request.meth request with
    | Error meth ->
      Log.info (fun m -> m "Ignoring unknown/unsupported method %S" meth);
      Cohttp_lwt_unix.Server.respond_string ~status: `Not_implemented ~body: (spf "unknown/unsupported method %S" meth) ()
    | Ok meth ->
      let uri = Request.uri request in
      let path = Uri.path uri in
      Log.debug (fun m -> m "%s %s" (Madge.Request.meth_to_string meth) path);
      Environment.with_' request @@ fun env ->
      if String.starts_with ~needle: "/api/" path then
        (
          Metrics.increment_http_requests_count `API;
          Log.debug (fun m -> m "Looking for an API controller for %s." path);
          let%lwt body = Cohttp_lwt.Body.to_string body in
          Pair.cons Environment.Add_session_cookie <$> apply_controller env (Madge.Request.make ~meth ~uri ~body)
        )
      else
        Static.serve env path (Uri.query uri)

  let () =
    Lwt.async_exception_hook :=
      (function
        | Unix.Unix_error (Unix.EPIPE, _, _) ->
          Log.warn (fun m -> m "Connection closed by the client")
        | exn ->
          log_exn ~msg: "Uncaught asynchronous exception" exn
      )

  let read_configuration () =
    Logger.bracket_lwt (module Log) "reading configuration" @@ fun () ->
    Config.parse_cmd_line ()

  let () =
    Prometheus_unix.Logging.init ();
    (* Tweak the default {!Logs.format_reporter} to print the level our way. *)
    let reporter =
      let level_to_color = function
        | Logs.Debug -> "\027[37m" (* gray *)
        | Info -> "\027[0m" (* reset to white *)
        | Warning -> "\027[33m" (* yellow *)
        | Error -> "\027[31m" (* red *)
        | App -> "\027[1m" (* white bold *)
      in Logs.format_reporter
        ~pp_header: (fun fmt (level, _header) ->
          fpf fmt "%s%s%s" (level_to_color level) (Logger.loglevel_to_string level) Logger.vsep
        )
        ()
    in
    (* Inject per-level counting of logs for Prometheus. *)
    let reporter = {
      Logs.report = fun src level ~over k msgf ->
        Prometheus_unix.Logging.inc_counter level (Logs.Src.name src);
        reporter.Logs.report src level ~over k msgf
    }
    in
    Logger.early_initialisation ~reporter

  let initialise_logs () =
    Logger.late_initialisation (Config.get ()).loglevel

  let write_pid () =
    let pid = Unix.getpid () in
    if (Config.get ()).pid_file <> "" then
      Lwt_io.(
        with_file ~mode: output (Config.get ()).pid_file @@ fun ochan ->
        fprintlf ochan "%d" pid
      )
    else
      lwt_unit

  let run_migrations () =
    Logger.bracket_lwt (module Log) "applying migrations" @@ fun () ->
    Database.apply_migrations ()

  let check_init_only () =
    if (Config.get ()).init_only then
      (
        Log.info (fun m -> m "Init only mode. Stopping now.");
        exit 0
      )

  let start_routines () =
    Logger.bracket (module Log) "starting routines" @@ fun () ->
    Routine.initialise ()

  let log_die () =
    Log.info (fun m -> m "Dying");
    exit 1

  let notify_systemd_ready () =
    Sys.getenv_opt "NOTIFY_SOCKET"
    |> Option.iter @@ fun path ->
      Log.debug (fun m -> m "Notifying systemd");
      let sock = Unix.socket Unix.PF_UNIX Unix.SOCK_DGRAM 0 in
      let addr = Unix.ADDR_UNIX path in
      let msg = "READY=1\n" in
      ignore (Unix.sendto sock (Bytes.of_string msg) 0 (String.length msg) [] addr);
      Unix.close sock;
      Log.debug (fun m -> m "Done notifying systemd")

  let run_server () =
    Log.debug (fun m -> m "Starting server");
    catchall
      ~place: "the server"
      ~die: log_die
      @@ fun () ->
      let wait_for_server =
        Server.create
          ~mode: (`TCP (`Port (Config.get ()).port))
          (Server.make ~callback ())
      in
      Log.info (fun m -> m "Server is up and running");
      notify_systemd_ready ();
      wait_for_server

  let () = Random.self_init ()
  let () = Printexc.record_backtrace true

  let main : unit Lwt.t =
    catchall
      ~place: "main"
      ~die: log_die
      @@ fun () ->
      read_configuration ();%lwt
      initialise_logs ();
      write_pid ();%lwt
      run_migrations ();%lwt
      check_init_only ();
      start_routines ();
      run_server ()

  let () = Lwt_main.run main
