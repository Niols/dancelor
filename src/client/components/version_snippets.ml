open Nes

open Dancelor_common
open Model_new
open Html

let make_svg_gen ?(show_logs = false) status_signal =
  let on_succeeded href = [
    object_
      ~a: [
        (* Tune previews are generated on A4 paper -- 21cm wide -- with a left margin
           of 1cm for page numbers -- that is 5% of the whole page. Since we want page
           numbers to actually appear in the margin on the website, we make the image
           bigger but remove those 5% of margin on the left. *)
        a_style "margin-left: -5%; width: 105%;";
        a_mime_type "image/svg+xml";
        a_data href;
      ]
      [
        Utils.Alert.make ~level: Danger [
          txt "This tune could not load. Try again, and, if the error persists, please contact your administrator or file a bug report."
        ]
      ]
  ]
  in
  R.div
    ~a: [
      (* On mobile, space gets parse, so we compensate the container's padding
         by a negative margin, making the tune container take almost the whole
         width (effectively hiding the bar numbers; see also below). *)
      a_class ["mx-n2"; "mx-sm-0"];
    ] @@
    (if show_logs then Job.show_live_status else Job.show_placeholder)
      ~on_succeeded
      status_signal

let make_ogg_gen status_signal =
  R.div
    ~a: [
      (* On mobile, space gets parse, so we compensate the container's padding
         by a negative margin, making the tune container take almost the whole
         width (effectively hiding the bar numbers; see also below). *)
      a_class ["mx-n2"; "mx-sm-0"];
    ]
    (
      let mk ?src classes = [audio ?src ~a: [a_controls (); a_class classes; a_style "zoom: 0.8";] []] in
      (* we go via an intermediary signal, so as to avoid the placeholder flickering
         on irrelevant changes of status *)
      S.flip_map (S.map Job.status_to_wait_status status_signal) @@ function
        | Waiting -> mk ["placeholder"]
        | Failed -> mk ["bg-danger"; "opacity-50"]
        | Succeeded src -> mk ~src []
        | Copyrighted -> []
    )

let make_gen
    ?show_logs
    ?(show_audio = true)
    ?(is_protected_promise = lwt_false)
    svg_status_signal
    ogg_status_signal
  =
  div [
    div ~a: [R.a_class (S.from_lwt [] @@ if%lwt is_protected_promise then lwt ["d-none"] else lwt_nil)] [
      div [make_svg_gen ?show_logs svg_status_signal];
      div ~a: [a_class ["mt-1"; "d-flex"; "justify-content-end"]] [
        (if show_audio then make_ogg_gen ogg_status_signal else div []);
      ];
    ];
    (
      let classes = ["alert"; "alert-warning"] in
      let classes_none = ["alert"; "alert-warning"; "d-none"] in
      div ~a: [R.a_class (S.from_lwt classes_none @@ if%lwt is_protected_promise then lwt classes else lwt classes_none)] [
        txt "You cannot see the content of this version because it is protected, for copyright reasons."
      ]
    );
  ]

let make_gen ?show_logs ?show_audio ~slug copyright_response_promise =
  let svg_status_signal =
    Job.status_signal (NesSlug.add_suffix slug ".svg") (
      Endpoints.Version.map_copyright_response
        (Endpoints.Job.map_registration_response Endpoints.Version.Snippet_ids.svg_job_id)
      <$> copyright_response_promise
    )
  in
  let ogg_status_signal =
    Job.status_signal (NesSlug.add_suffix slug ".ogg") (
      Endpoints.Version.map_copyright_response
        (Endpoints.Job.map_registration_response Endpoints.Version.Snippet_ids.ogg_job_id)
      <$> copyright_response_promise
    )
  in
  make_gen
    ?show_logs
    ?show_audio
    svg_status_signal
    ogg_status_signal

let make ?show_logs ?show_audio ?(params = Model.Version_parameters.none) (version : Version_name.t) =
  make_gen
    ?show_logs
    ?show_audio
    ~slug: (NesSlug.of_string version.name)
    (
      Madge_client.call_exn
        Endpoints.Api.(route @@ Version Build_snippets)
        version.id
        params
        Rendering_parameters.none
    )

let make_preview ?show_logs ?show_audio ?(params = Model.Version_parameters.none) slug version =
  make_gen
    ?show_logs
    ?show_audio
    ~slug
    (
      let%lwt payload =
        Madge_client.call_exn
          Endpoints.Api.(route @@ Version Build_snippets')
          version
          params
          Rendering_parameters.none
      in
      lwt @@ Endpoints.Version.Granted {payload; reason = Non_copyrighted}
    )
