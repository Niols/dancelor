open Js_of_ocaml
open Nes
open Dancelor_common
open Html
open Utils

(** Similar to {!Endpoints.Job.Status.t} but with additional [Registering]
    and [Copyrighted], and with “Succeeded” carrying the path.  *)
type status =
  | Registering
  | Pending
  | Running of string list
  | Failed of string list
  | Succeeded of Uri.t
  | Copyrighted
[@@deriving yojson]

(** Same as {!status_signal} but returns a stream of statuses from all the times that
    we check with the server. The stream closes once the job has succeeded or failed. *)
let status_stream slug (promise : Job_id.t Endpoints.Job.registration_response Endpoints.Version.copyright_response Lwt.t) : status Lwt_stream.t =
  Lwt_stream.(concat % return_lwt') @@
    match%lwt promise with
    | Protected -> lwt @@ Lwt_stream.return Copyrighted
    | Granted {payload; _} ->
      match payload with
      | Endpoints.Job.Already_succeeded job_id ->
        lwt @@ Lwt_stream.return (Succeeded (Endpoints.Api.(href @@ Job File) job_id slug))
      | Endpoints.Job.Registered job_id ->
        lwt @@
        Lwt_stream.from_next @@ fun () ->
        Js_of_ocaml_lwt.Lwt_js.sleep 2.;%lwt
        let%lwt status = Api.call_exn (Job Status) job_id in
        lwt @@
          match status with
          | Pending -> Lwt_stream.Next Pending
          | Running logs -> Lwt_stream.Next (Running logs)
          | Failed logs -> Lwt_stream.Last (Failed logs)
          | Succeeded -> Lwt_stream.Last (Succeeded (Endpoints.Api.(href @@ Job File) job_id slug))

(** Given a promise to a [Job_id.t Endpoints.Job.registration_response],
    contact the server to check the job's status and return a signal that tracks it. *)
let status_signal slug (promise : Job_id.t Endpoints.Job.registration_response Endpoints.Version.copyright_response Lwt.t) : status S.t =
  S.from_lwt_stream Registering (status_stream slug promise)

let status_signal_non_copyrighted slug (promise : Job_id.t Endpoints.Job.registration_response Lwt.t) : status S.t =
  status_signal
    slug
    (
      let%lwt payload = promise in
      lwt @@ Endpoints.Version.Granted {payload; reason = Non_copyrighted}
    )

let show_logs logs = pre ~a: [a_style "white-space: pre-wrap;"] [small [txt (String.concat "\n" logs)]]

let spinner () =
  let spinner =
    div ~a: [a_class ["d-flex"; "justify-content-center"; "pb-4"]] [
      div ~a: [a_class ["spinner-border"]; a_role ["status"]] [];
    ]
  in
  let spinner_dom = To_dom.of_div spinner in
  Lwt.async (fun () ->
    Js_of_ocaml_lwt.Lwt_js.sleep 0.1;%lwt
    spinner_dom##scrollIntoView Js._false;
    lwt_unit
  );
  spinner

let ohnoes () =
  let ohnoes =
    div ~a: [a_class ["d-flex"; "justify-content-center"; "pb-4"]] [
      txt "oh noes :-("
    ]
  in
  let ohnoes_dom = To_dom.of_div ohnoes in
  Lwt.async (fun () ->
    Js_of_ocaml_lwt.Lwt_js.sleep 0.1;%lwt
    ohnoes_dom##scrollIntoView Js._false;
    lwt_unit
  );
  ohnoes

let show_live_status ~on_succeeded status_signal =
  S.flip_map status_signal @@ function
    | Registering ->
      [
        Alert.make ~level: Info ~icon: (Job Registering) [
          txt
            "The document generation job is being sent to the server.";
        ];
        div ~a: [a_class ["mt-4"]] [show_logs []; spinner ()];
      ]
    | Pending ->
      [
        Alert.make
          ~level: Info
          ~icon: (Job Pending)
          [
            txt
              "The document generation job is pending, that is it has been \
             registered on the server, but the server is busy with other jobs. \
             Go get yourself a tea.";
          ];
        div ~a: [a_class ["mt-4"]] [show_logs []; spinner ()];
      ]
    | Running logs ->
      [
        Alert.make ~level: Info ~icon: (Job Running) [
          txt
            "The server has started generating the document. This process can be \
           short for single tunes, but can also take a (very) long time, up to \
           several minutes, for big books. Go get yourself a tea.";
        ];
        div ~a: [a_class ["mt-4"]] [show_logs logs; spinner ()];
      ]
    | Copyrighted ->
      [
        Alert.make ~level: Warning [
          txt "You cannot see the content of this version because it is protected, for copyright reasons.";
        ]
      ]
    | Failed logs ->
      [
        Alert.make ~level: Danger [
          txt
            "There was a problem during document generation, presumably because \
           the LilyPond of a tune is erroneous. Fix the error, or report an \
           issue.";
        ];
        div ~a: [a_class ["mt-4"]] [show_logs logs; ohnoes ()];
      ]
    | Succeeded href -> on_succeeded href

(** An intermediary status conflating all the “wait” status. This is useful in
    signal, eg. to avoid placeholders flickering on irrelevant changes *)
type wait_status =
  | Waiting
  | Failed
  | Succeeded of Uri.t
  | Copyrighted

let status_to_wait_status : status -> wait_status = function
  | Succeeded href -> Succeeded href
  | Failed _ -> Failed
  | Copyrighted -> Copyrighted
  | Registering | Pending | Running _ -> Waiting

(** Variant of {!job_live_status} that only shows a placeholder on all waiting
    statuses. It is meant to be used in places where people should not be
    exposed to logs. *)
let show_placeholder ~on_succeeded status_signal =
  S.flip_map (S.map status_to_wait_status status_signal) @@ function
    | Waiting -> [div_placeholder ~min: 12 ~max: 20 ()]
    | Succeeded href -> on_succeeded href
    | Failed ->
      [
        Alert.make ~level: Danger [
          txt
            "There was a problem during document generation, presumably because \
           the LilyPond of a tune is erroneous. Fix the error, or report an \
           issue.";
        ];
      ]
    | Copyrighted ->
      [
        Alert.make ~level: Warning [
          txt "You cannot see the content of this version because it is protected, for copyright reasons.";
        ]
      ]
