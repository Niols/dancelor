open Nes
open Dancelor_common
open Html
open Utils
open Components

include Endpoints.Page.Make_describe(Model)

let open_dialog page =
  let%lwt maybe_reporter_input =
    match Environment.actor_now () with
    | Some actor ->
      lwt_left (`Connected, Input.inactive ~label: "Reporter" (Username.to_string @@ Model.User.username' actor))
    | None ->
      right
      <$> Input.make
          ~type_: Text
          ~label: "Reporter"
          ~placeholder: "Dr Jean Milligan"
          ~serialise: Fun.id
          ~validate: (S.const % Result.of_string_nonempty ~empty: "You must specify the reporter.")
          ""
  in
  let%lwt source =
    Lwt.bind (describe page) @@ function
      | None ->
        Choices.make_radios
          ~label: "Source of the issue"
          [
            Choices.choice ~value: true [txt "Dancelor itself"] ~checked: true;
          ]
      | Some (kind, name) ->
        Choices.make_radios
          ~label: "Source of the issue"
          [
            Choices.choice ~value: false [txt @@ spf "This %s: %s" kind name];
            Choices.choice ~value: true [txt "Dancelor itself"];
          ]
  in
  let%lwt title_input =
    Input.make
      ~type_: Text
      ~label: "Title"
      ~placeholder: "Blimey, 'tis not working!"
      ~serialise: Fun.id
      ~validate: (S.const % Result.of_string_nonempty ~empty: "The title cannot be empty.")
      ""
  in
  let%lwt description_input =
    Input.make
      ~type_: (Textarea {rows = 15})
      ~label: "Description"
      ~placeholder: "I am gutted; this knock off tune is wonky at best!"
      ~serialise: Fun.id
      ~validate: (S.const % ok)
      ""
  in
  let request_signal =
    S.map Result.to_option @@
    RS.bind (match maybe_reporter_input with Left (user, _) -> S.const (ok (left user)) | Right reporter_input -> S.map (Result.map right) (Component.signal reporter_input)) @@ fun reporter ->
    RS.bind (Component.signal title_input) @@ fun title ->
    RS.bind (Component.signal description_input) @@ fun description ->
    RS.bind (Component.signal source) @@ fun source ->
    RS.pure Endpoints.Issue_report.Request.{reporter; page; source_is_dancelor = source; title; description}
  in
  let%lwt response =
    Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "Report an issue")
      ~on_load: (fun () -> Component.focus @@ match maybe_reporter_input with Left _ -> title_input | Right reporter_input -> reporter_input)
      [(
        match maybe_reporter_input with
        | Left (_, inactive_reporter_input) -> inactive_reporter_input
        | Right reporter_input -> Component.html reporter_input
      );
      Component.html source;
      Component.html title_input;
      Component.html description_input;
      ]
      ~buttons: [
        Button.cancel' ~return ();
        Button.make
          ~label: "Report"
          ~label_processing: "Reporting..."
          ~icon: (Other Bug)
          ~classes: ["btn-primary"]
          ~disabled: (S.map Option.is_none request_signal)
          ~onclick: (fun () ->
            Option.fold
              (S.value request_signal)
              ~none: lwt_unit
              ~some: (fun request ->
                let%lwt response = Madge_client.call_exn Endpoints.Api.(route Report_issue) request in
                return @@ Some response;
                lwt_unit
              )
          )
          ();
      ]
  in
  (
    match response with
    | Some response ->
      Toast.open_
        ~title: "Issue reported"
        [
          txt "Your issue has been reported as: ";
          a ~a: [a_href response.uri; a_target "_blank"] [txt @@ spf "%s (#%d)" response.title response.id];
          txt " You can track its progress there.";
        ]
    | None ->
      Toast.open_
        ~title: "Issue not reported"
        [
          txt
            "Your issue has not been reported, as you closed the dialog. If this \
             is an error, please contact your system administrator."
        ]
  );
  lwt_unit
