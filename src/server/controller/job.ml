open NesUnix
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.job": Logs.LOG)

let lifetime_memory_cache = 3600 (* one hour *)
let lifetime_nix_gc_roots = 24 * 3600 (* one day *)

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
    let cutoff = Unix.time () -. float_of_int older_than_sec in
    Monadise_lwt.lift_1_1
      Array.iter
      (fun fname ->
        let path = Filename.concat dir fname in
        try%lwt
          let%lwt stat = Lwt_unix.lstat path in
          if stat.Unix.st_mtime < cutoff then
            Lwt_unix.unlink path
          else
            lwt_unit
        with
          | Unix.Unix_error (Unix.ENOENT, _, _) -> lwt_unit
      )
      (Sys.readdir dir)
end

type state =
  | Pending
  | Running of {process: Lwt_process.process_full; stderr: string list ref}
  | Failed of {status: Unix.process_status; logs: string list}
  | Succeeded of {path: string}

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

let register_job ~add_pending (expr : expr) : job =
  match Cache.get ~cache: job_of_expr ~key: expr with
  | Some job when not (is_failed !(job.state)) ->
    (*  if there is a job for the same expression, but not necessarily the
        same file, we can just return without starting an actual job; we do
        not do so for failed job in case the failure was transient *)
    Log.debug (fun m -> m "Found existing and non-failed job");
    job
  | _ ->
    (* otherwise, we really do have to register a new job *)
    let job = {expr; state = ref Pending} in
    (* NOTE: we use {!Hashtbl.replace} because {!Hashtbl.add} might keep failed jobs *)
    Cache.set ~cache: job_of_expr ~key: expr ~value: job;
    if add_pending then add_pending_job (Some job);
    Log.debug (fun m -> m "Registered new job: %s" (expr_val expr));
    job

let register_job_and_file (expr : expr) (file : string) : Job_id.t Endpoints.Job.registration_response =
  Log.debug (fun m -> m "register_job");
  let job = register_job ~add_pending: true expr in
  let job_and_file = {id = Job_id.create (); job; file} in
  Cache.set ~cache: job_and_file_of_id ~key: job_and_file.id ~value: job_and_file;
  (* shortcut for when the job is already successful. this is not possible with
     new job, but will often happen with cache hits. it saves one network call
     by allowing the client to request the file immediately *)
  match !(job_and_file.job.state) with
  | Succeeded _ -> Already_succeeded job_and_file.id
  | _ -> Registered job_and_file.id

let run_job job =
  match !(job.state) with
  | Running _ -> invalid_arg "run_job: cannot start a job that is already started"
  | Failed _ -> invalid_arg "run_job: cannot start a job that has already failed"
  | Succeeded _ -> invalid_arg "run_job: cannot start a job that has already succeeded"
  | Pending ->
    let%lwt path = Nix_gc_root.make_path () in
    let command = [|"nix-build"; "--impure"; "--out-link"; path; "--expr"; expr_val job.expr|] in
    let process = Lwt_process.open_process_full ("", command) in
    let stderr = ref [] in
    job.state := Running {process; stderr};
    Lwt_io.close process#stdin;%lwt
    Lwt.async (fun () ->
      let rec follow_stderr () =
        match%lwt Lwt_io.read_line_opt process#stderr with
        | None -> lwt_unit
        | Some line -> stderr := !stderr @ [line]; follow_stderr ()
      in
      follow_stderr ()
    );
    (* block until the job is done running *)
    let%lwt status = process#status in
    let%lwt stdout = Lwt_io.read process#stdout in
    let%lwt last_stderr = String.split_on_char '\n' <$> Lwt_io.(atomic read process#stderr) in
    let stderr = !stderr @ last_stderr in
    Log.debug (fun m -> m "Ran job: %s" (expr_val job.expr));
    Log.debug (fun m -> m "Status: %a" Process.pp_process_status status);
    Log.debug (fun m -> m "%a" (Format.pp_multiline_sensible "Stdout") stdout);
    Log.debug (fun m -> m "%a" (Format.pp_multiline_sensible "Stderr") (String.concat "\n" stderr));
    (
      job.state :=
        match status with
        | WEXITED 0 -> Succeeded {path}
        | _ -> Failed {status; logs = stderr}
    );
    lwt_unit

let make expr = lwt {expr; state = ref Pending}

let get id =
  match Cache.get ~cache: job_and_file_of_id ~key: id with
  | None -> Madge_server.shortcut_not_found "This job does not exist anymore, or has never existed."
  | Some job_and_file -> lwt job_and_file

let status id =
  Log.debug (fun m -> m "status %s" (Job_id.to_string id));
  get id >>= fun {job; _} ->
  lwt @@
    match !(job.state) with
    | Pending -> Endpoints.Job.Status.Pending
    | Running {stderr; _} -> Running !stderr
    | Failed {logs; _} -> Failed logs
    | Succeeded _ -> Succeeded

let file id slug =
  Log.debug (fun m -> m "file %s %s" (Job_id.to_string id) (NesSlug.to_string slug));
  get id >>= fun {job; file; _} ->
  match !(job.state) with
  | Pending -> Madge_server.shortcut_bad_request "This job is not running yet, you cannot query the file."
  | Running _ -> Madge_server.shortcut_bad_request "This job is still running, you cannot query the file."
  | Failed _ -> Madge_server.shortcut_bad_request "This job failed, you cannot query the file."
  | Succeeded {path} -> Madge_server.respond_file ~fname: (Filename.concat path file)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Job.t -> a = fun _env endpoint ->
  match endpoint with
  | Status -> status
  | File -> file
