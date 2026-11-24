open Nes_unix
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.job": Logs.LOG)
let namespace = "dancelor_job"

let lifetime_memory_cache = Time.duration_of_hours 12.
let lifetime_nix_gc_roots = Time.duration_of_days 2.

(** Dancelor builds objects with Nix and leaves them in the Nix store, relying
    on the Nix garbage collector to clean them up eventually. However, the Nix
    GC might trigger too early, so we keep GC roots for a while to protect our
    artifacts. *)
module Nix_gc_root = struct
  (** A temporary directory to hold Nix GC roots. It should be cleaned up every
      now and then, without which the Nix store would never stop growing. *)
  let dir =
    let dir = Filename.concat Config.temp_dir "nix-gc-roots" in
    Sys.mkdir dir 0o700;
    dir

  (** Make a path in the Nix GC root folder. Ensure that no file exists at that
      path; suitable for nix-build's --out-link argument.  *)
  let make_path () =
    let path = Filename.temp_file ~temp_dir: dir "" "" in
    Lwt_unix.unlink path;%lwt lwt path

  (** Remove links in the Nix GC root folder that are older than the given
      argument. This does not remove anything from the Nix store but releases
      the root on them such that the Nix GC may decide to clean them up. *)
  let clean ~older_than_sec =
    let cutoff = Time.make_in_the_past older_than_sec in
    Monadise_lwt.lift_1_1
      Array.iter
      (fun fname ->
        let path = Filename.concat dir fname in
        try%lwt
          let%lwt stat = Lwt_unix.lstat path in
          if Time.compare (Time.of_timestamp stat.Unix.st_mtime) cutoff < 0 then
            Lwt_unix.unlink path
          else
            lwt_unit
        with
          | Unix.Unix_error (Unix.ENOENT, _, _) -> lwt_unit
      )
      (Sys.readdir dir)

  let number_of_roots () =
    try Array.length (Sys.readdir dir) with Sys_error _ -> 0
end

type state =
  | Pending of {since: Time.t}
  | Running of {
      process: Lwt_process.process_full; [@opaque]
      stderr: string list ref; [@opaque]
    }
  | Failed of {
      status: Unix.process_status; [@opaque]
      logs: string list; [@opaque]
    }
  | Succeeded of {path: string}
[@@deriving show]

let is_failed = function Failed _ -> true | _ -> false

let succeeded_val_path = function
  | Succeeded {path} -> Some path
  | _ -> None

(** A type for Nix expressions. *)
type expr = Expr of string
let expr_val (Expr s) = s

(** An internal job. This is an actual job, producing potentially several
    artifacts. A {!Job_id.t} corresponds to an {!job_and_file}, which is an
    internal job AND a specific artifact within this job. This allows building
    several things at the same time, while still giving a simple “one job = one
    file” interface to the client. *)
type job = {
  kind: string; (** for metrics *)
  expr: expr;
  state: state ref;
}

(* NOTE: The following table and stream need to be kept in sync. *)
let job_of_expr : (expr, job) Cache.t = Cache.create ~lifetime: lifetime_memory_cache ()
let (pending_jobs : job Lwt_stream.t), add_pending_job = Lwt_stream.create ()

(** An job and a file within that job. See comment for {!job}. *)
type job_and_file = {
  id: Job_id.t; (** used to identify a job when communicating with the client *)
  job: job;
  file: string; (** path of the file in the Nix output *)
}

(** NOTE: This needs to be kept in sync with {!job_of_expr} and {!pending_jobs},
    namely each registered {!job_and_file} should point to {!job} that is
    registered in {!job_of_expr}. *)
let job_and_file_of_id : (Job_id.t, job_and_file) Cache.t = Cache.create ~lifetime: lifetime_memory_cache ()

let cache_size =
  let family =
    Prometheus.Gauge.v_labels
      ~namespace
      ~help: "Number of job-related artifact in various caches"
      "cache_size"
      ~label_names: ["cache"]
  in
  fun ~cache ->
    Prometheus.Gauge.labels family [cache]

let () =
  let set_cache_size cache value =
    Prometheus.Gauge.set (cache_size ~cache) (float_of_int value)
  in
  Prometheus.CollectorRegistry.(register_pre_collect default) (fun () ->
    set_cache_size "Nix GC roots" (Nix_gc_root.number_of_roots ());
    set_cache_size "job_of_expr" (Cache.size ~cache: job_of_expr);
    set_cache_size "job_and_file_of_id" (Cache.size ~cache: job_and_file_of_id);
  )

let registered_jobs_total =
  let family =
    Prometheus.Counter.v_labels
      ~namespace
      ~help: "Number of registered jobs"
      "registered_jobs_total"
      ~label_names: ["kind"; "cache_hit"]
  in
  fun ~kind ~cache ->
    Prometheus.Counter.labels family [kind; (match cache with `Hit -> "cache_hit" | `Miss -> "cache_miss")]

let register_job ~kind ~add_pending (expr : expr) : job =
  Log.debug (fun m -> m "register_job ~kind:%s ~add_pending:%b <expr>@\n  expr: %s" kind add_pending (expr_val expr));
  match Cache.get ~cache: job_of_expr ~key: expr with
  | Some job when not (is_failed !(job.state)) ->
    (*  if there is a job for the same expression, but not necessarily the
        same file, we can just return without starting an actual job; we do
        not do so for failed job in case the failure was transient *)
    Log.debug (fun m -> m "Found existing and non-failed job");
    Prometheus.Counter.inc_one (registered_jobs_total ~kind ~cache: `Hit);
    job
  | _ ->
    (* otherwise, we really do have to register a new job *)
    let job = {kind; expr; state = ref (Pending {since = Time.now ()})} in
    Cache.set ~cache: job_of_expr ~key: expr ~value: job;
    if add_pending then add_pending_job (Some job);
    Log.debug (fun m -> m "Registered new job: %s" (expr_val expr));
    Prometheus.Counter.inc_one (registered_jobs_total ~kind ~cache: `Miss);
    job

let register_job_and_file ~kind (expr : expr) (file : string) : Job_id.t Endpoints.Job.registration_response =
  let job = register_job ~kind ~add_pending: true expr in
  let job_and_file = {id = Job_id.create (); job; file} in
  Cache.set ~cache: job_and_file_of_id ~key: job_and_file.id ~value: job_and_file;
  (* shortcut for when the job is already successful. this is not possible with
     new job, but will often happen with cache hits. it saves one network call
     by allowing the client to request the file immediately *)
  match !(job_and_file.job.state) with
  | Succeeded _ -> Already_succeeded job_and_file.id
  | _ -> Registered job_and_file.id

(** Given a string representing one log line of Nix, return a cleaned up version
    hiding Nix-specific things. This is meant for end users, who don't need to
    know the nitty gritty, to give them a more understandable output. *)
let clean_nix_log_line =
  let store_path_prefix_regexp = Str.regexp "/nix/store/[a-z0-9]*-" in
  let drv_suffix_regexp = Str.regexp "\\.drv" in
  let derivation_regexp = Str.regexp "derivation" in
  fun (line : string) ->
    line
    |> Str.global_replace store_path_prefix_regexp ""
    |> Str.global_replace drv_suffix_regexp ""
    |> Str.global_replace derivation_regexp "object"

(** Given references holding a cleaned up version of stderr, add a Nix log line
    to it. Log lines are cleaned with {!clean_nix_log_line} and the last error
    block repeating the last X log lines is ignored.  *)
let make_add_nix_log_line clean_stderr =
  (* whether the last log line was an `error: `, possibly indicating the
     beginning of the Nix error block *)
  let last_stderr_line_was_error = ref false in
  let in_nix_error_block = ref false in
  fun (line : string) ->
    let add_line =
      if !in_nix_error_block then
        false
      else if !last_stderr_line_was_error then
        (
          if String.starts_with ~needle: "       Reason: " line then
            (
              in_nix_error_block := true;
              false
            )
          else
            (
              last_stderr_line_was_error := false;
              true
            )
        )
      else
        (
          if String.starts_with ~needle: "error: " line then
            last_stderr_line_was_error := true;
          true
        )
    in
    if add_line then
      clean_stderr := !clean_stderr @ [clean_nix_log_line line]

(** An exponential histogram with 17 buckets ranging from 10ms to 100s. 17 buckets mean:
    0 - 10ms - 18ms - 32ms - 56ms - 100ms
    - 178ms - 316ms - 562ms - 1s
    - 1.8s - 3.2s - 5.6s - 10s
    - 18s - 32s - 56s - 100s - infinity *)
module Exponential_10ms_100s_histogram = Prometheus.Histogram(struct
  let spec = Prometheus.Histogram_spec.of_exponential 0.01 (10. ** 0.25) 17
end)

let job_duration_seconds =
  let family =
    Exponential_10ms_100s_histogram.v_labels
      ~namespace
      ~help: "Duration of each stage of a job in seconds"
      "duration_seconds"
      ~label_names: ["kind"; "state"]
  in
  fun ~kind ~state ->
    let state = match state with `Before -> "before" | `Pending -> "pending" | `Running -> "running" in
    Exponential_10ms_100s_histogram.labels family [kind; state]

let prepare_and_register_job_and_file ~kind make_expr_and_file : Job_id.t Endpoints.Job.registration_response Lwt.t =
  let%lwt (expr, file) = Exponential_10ms_100s_histogram.time (job_duration_seconds ~kind ~state: `Before) Unix.gettimeofday make_expr_and_file in
  lwt @@ register_job_and_file ~kind expr file

let run_job job =
  match !(job.state) with
  | Running _ -> invalid_arg "run_job: cannot start a job that is already started"
  | Failed _ -> invalid_arg "run_job: cannot start a job that has already failed"
  | Succeeded _ -> invalid_arg "run_job: cannot start a job that has already succeeded"
  | Pending {since} ->
    let start_time = Time.now () in
    let pending_duration = Time.diff start_time since in
    Log.debug (fun m -> m "Running job starting at %a, pending for %a" Time.pp start_time Time.pp_duration_pretty pending_duration);
    Exponential_10ms_100s_histogram.observe (job_duration_seconds ~kind: job.kind ~state: `Pending) (Time.duration_to_seconds pending_duration);
    let%lwt path = Nix_gc_root.make_path () in
    let command = [|"nix-build"; "--impure"; "--out-link"; path; "--expr"; expr_val job.expr|] in
    let process = Lwt_process.open_process_full ("", command) in
    let stderr = ref [] in
    let clean_stderr = ref [] in
    let add_stderr_line =
      let add_nix_log_line = make_add_nix_log_line clean_stderr in
      fun line ->
        stderr := !stderr @ [line];
        add_nix_log_line line
    in
    job.state := Running {process; stderr = clean_stderr};
    Lwt_io.close process#stdin;%lwt
    Lwt.async (fun () ->
      let rec follow_stderr () =
        match%lwt Lwt_io.read_line_opt process#stderr with
        | None -> lwt_unit
        | Some line -> add_stderr_line line; follow_stderr ()
      in
      follow_stderr ()
    );
    (* block until the job is done running *)
    let%lwt status = process#status in
    let%lwt stdout = Lwt_io.read process#stdout in
    let%lwt last_stderr = String.split_on_char '\n' <$> Lwt_io.(atomic read process#stderr) in
    List.iter add_stderr_line last_stderr;
    Log.debug (fun m -> m "Ran job: %s" (expr_val job.expr));
    Log.debug (fun m -> m "Status: %a" Process.pp_process_status status);
    Log.debug (fun m -> m "%a" (Format.pp_multiline_sensible "Stdout") stdout);
    Log.debug (fun m -> m "%a" (Format.pp_multiline_sensible "Stderr") (String.concat "\n" !stderr));
    (
      job.state :=
        match status with
        | WEXITED 0 -> Succeeded {path}
        | _ -> Failed {status; logs = !clean_stderr}
    );
    let running_duration = Time.duration_to_now start_time in
    Log.debug (fun m -> m "Dune running job in %a, started at %a" Time.pp_duration_pretty running_duration Time.pp start_time);
    Exponential_10ms_100s_histogram.observe (job_duration_seconds ~kind: job.kind ~state: `Running) (Time.duration_to_seconds running_duration);
    lwt_unit

let get id =
  match Cache.get ~cache: job_and_file_of_id ~key: id with
  | None -> Madge_server.shortcut_not_found "This job does not exist anymore, or has never existed."
  | Some job_and_file -> lwt job_and_file

let status id =
  Log.debug (fun m -> m "status %s" (Job_id.to_string id));
  Lwt_unix.sleep 0.1;%lwt
  get id >>= fun {job; _} ->
  lwt @@
    match !(job.state) with
    | Pending _ -> Endpoints.Job.Status.Pending
    | Running {stderr; _} -> Running !stderr
    | Failed {logs; _} -> Failed logs
    | Succeeded _ -> Succeeded

let file id slug =
  Log.debug (fun m -> m "file %s %s" (Job_id.to_string id) (NesSlug.to_string slug));
  get id >>= fun {job; file; _} ->
  match !(job.state) with
  | Pending _ -> Madge_server.shortcut_bad_request "This job is not running yet, you cannot query the file."
  | Running _ -> Madge_server.shortcut_bad_request "This job is still running, you cannot query the file."
  | Failed _ -> Madge_server.shortcut_bad_request "This job failed, you cannot query the file."
  | Succeeded {path} -> Madge_server.respond_file ~fname: (Filename.concat path file)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Job.t -> a = fun _env endpoint ->
  match endpoint with
  | Status -> status
  | File -> file
