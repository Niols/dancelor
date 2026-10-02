open Nes
open Dancelor_common
open Model_new
open Html
open Utils
open Model_builder.Core

(* REVIEW: This is close to `Version_download_dialog.t`; there is room for
   factorisation here. *)
type t = {
  choice_rows: Html_types.div elt list;
  parameters_signal: (Set_parameters.t * Rendering_parameters.t) React.signal;
}

let lift_version_parameters every_version =
  Set_parameters.make ~every_version ()

let create () =
  let%lwt version_dialog = Version_download_dialog.create () in
  let%lwt headers_choices =
    Components.Choices.(
      make_radios
        ~label: "Show headers and footers"
        [
          choice' [txt "Yes"] ~checked: true;
          choice'
            [txt "No"]
            ~value: (
              Set_parameters.none,
              Rendering_parameters.make ~show_headers: false ()
            );
        ]
    )
  in
  lwt {
    choice_rows = version_dialog.choice_rows @ [
      Components.Component.html headers_choices
    ];
    parameters_signal =
    let no_parameters = (Set_parameters.none, Rendering_parameters.none) in
    S.merge
      (Pair.map2 Set_parameters.compose Rendering_parameters.compose)
      no_parameters
      [
        S.map (Pair.map_fst lift_version_parameters) version_dialog.parameters_signal;
        S.map (Option.value ~default: no_parameters % Option.join % Result.to_option) (Components.Component.signal headers_choices);
      ];
  }

(* REVIEW: This is extremely close to `Version_download_dialog.render` (apart for
   one line and one type, really); there is room for factorisation here. *)
let open_ (set : Set_view.t) dialog =
  Page.open_dialog @@ fun return ->
  Page.make'
    ~title: (lwt "Download a PDF")
    [div dialog.choice_rows]
    ~buttons: [
      Button.cancel' ~return ();
      Button.download
        ~onclick: (fun () ->
          let (set_params, rendering_params) = S.value dialog.parameters_signal in
          return None;
          Version_download_dialog.open_pdf_generation_dialog (
            Job.status_signal_non_copyrighted
              (NesSlug.add_suffix (NesSlug.of_string set.name) ".pdf")
              (Api.call_exn (Set Build_pdf) set.id set_params rendering_params)
          )
        )
        ();
    ]

let create_and_open set = open_ set =<< create ()
