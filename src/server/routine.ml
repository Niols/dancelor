open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.routine": Logs.LOG)

(** A stream containing all the versions of the database. It never ends, and
    instead returns all the versions again, after a delay of 10 minutes. *)
let all_versions =
  let start_time = ref None in
  Lwt_stream.concat @@
  Lwt_stream.from @@ fun () ->
  (
    match !start_time with
    | None -> ()
    | Some start_time ->
      let duration = Datetime.(diff (now ()) start_time) in
      Log.info (fun m -> m "Done crawling all versions for pre-rendering in %.0fs" duration);
      if duration >= 2. *. float_of_int Controller.Job.lifetime_memory_cache then
        Log.warn (fun m -> m "The pre-rendering crawl takes too long compared to the in-memory cache's lifetime for comfort. Duration: %.0fs; cache's lifetime: %ds" duration Controller.Job.lifetime_memory_cache)
  );
  Lwt_unix.sleep 600.;%lwt
  let now = Datetime.now () in
  start_time := Some now;
  let%lwt all_versions = Database.Version.get_all_forms () in
  Log.info (fun m -> m "Starting to crawl all %d versions for pre-rendering at %a" (List.length all_versions) Datetime.pp now);
  lwt_some @@ Lwt_stream.of_list all_versions

(** A stream of prerendering jobs for versions in the database. This
    contains only pending and failed jobs, the others do not need to
    run again. *)
let all_versions_prerendering_job =
  Lwt_stream.filter_map_s
    (fun (version : Version_form.t) ->
      match version.content with
      | No_content -> lwt_none
      | _ ->
        let%lwt job =
          Controller.Job.register_job ~kind: "version-snippets" ~add_pending: false
          <$> Controller.Version.render_snippets version
        in
        match !(job.state) with
        | Failed _ | Pending _ -> lwt_some job
        | _ -> lwt_none
    )
    all_versions

let jobs_ran =
  let family =
    Prometheus.Counter.v_labels
      ~namespace: Controller.Job.namespace
      ~help: "Number of jobs ran since the beginning"
      "jobs_ran_total"
      ~label_names: ["queue"; "result"]
  in
  fun ~queue ~result ->
    Prometheus.Counter.labels family [queue; (match result with `Success -> "success" | `Error -> "error")]

let run_jobs_from ~queue_name ~max_concurrency =
  Lwt_stream.iter_n
    ~max_concurrency
    (fun job ->
      try%lwt
        Logger.bracket_lwt ~level_after: Debug (module Log) (spf "running job in queue %s: %s" queue_name Controller.Job.(expr_val job.expr)) (fun () ->
          Controller.Job.run_job job
        );%lwt
        Prometheus.Counter.inc_one (jobs_ran ~queue: queue_name ~result: `Success);
        lwt_unit
      with
        | exn ->
          Prometheus.Counter.inc_one (jobs_ran ~queue: queue_name ~result: `Error);
          !(Lwt.async_exception_hook) exn;
          lwt_unit
    )

let initialiase_job_runners ~threads =
  (* NOTE: There used to be something fancy where we had exactly
     [threads] threads, and one would pick up pre-rendering jobs when
     there was no pending job. As it turns out, reading in several
     places from the same stream is not safe and can lead to
     duplicates. There are ways around it, but the amount of code that
     it produces is not worth the trouble. *)
  Lwt.async (fun () ->
    Lwt.join [
      run_jobs_from ~queue_name: "prerender" ~max_concurrency: 1 all_versions_prerendering_job;
      run_jobs_from ~queue_name: "pending" ~max_concurrency: threads Controller.Job.pending_jobs;
    ]
  )

let rec clean_nix_gc_roots () =
  let number_before = Controller.Job.Nix_gc_root.number_of_roots () in
  Log.info (fun m -> m "Starting cleanup of Nix GC roots; %d roots before" number_before);
  Controller.Job.Nix_gc_root.clean ~older_than_sec: Controller.Job.lifetime_nix_gc_roots;%lwt
  let number_after = Controller.Job.Nix_gc_root.number_of_roots () in
  let period = Controller.Job.lifetime_nix_gc_roots / 10 in
  Log.info (fun m -> m "Done with cleanup of Nix GC roots (%d -> %d); waiting %ds" number_before number_after period);
  Lwt_unix.sleep (float_of_int period);%lwt
  clean_nix_gc_roots ()

let initialise_nix_gc_roots_cleanup () =
  Lwt.async (fun () ->
    clean_nix_gc_roots ()
  )

let initialise () =
  initialiase_job_runners ~threads: (Config.get ()).routine_threads;
  initialise_nix_gc_roots_cleanup ()
