open Js_of_ocaml
open Nes
open Dancelor_common
open Html
open Utils
open Components

type t = {
  choice_rows: Html_types.div elt list;
  parameters_signal: (Version_parameters.t * Rendering_parameters.t) React.signal;
}

(* TODO: Unicode flat in the rendering *)

let create () =
  let%lwt key_choices =
    Choices.(
      make_radios
        ~label: "Key"
        [
          choice' [txt "C"] ~checked: true;
          choice'
            [txt "B♭"]
            ~value: (
              Version_parameters.make ~transposition: (Music.Transposition.from_semitones 2) (),
              Rendering_parameters.make ~instruments: "Bb instruments" ()
            );
          choice'
            [txt "E♭"]
            ~value: (
              Version_parameters.make ~transposition: (Music.Transposition.from_semitones (-3)) (),
              Rendering_parameters.make ~instruments: "Eb instruments" ()
            );
        ]
    )
  in
  let%lwt clef_choices =
    Choices.(
      make_radios
        ~label: "Clef"
        [
          choice' [txt @@ Music.Clef.(to_symbol Treble)] ~checked: true;
          choice'
            [txt @@ Music.Clef.(to_symbol Alto)]
            ~value: (Version_parameters.make ~clef: Alto (), Rendering_parameters.make ~clef: "alto clef" ());
          choice'
            [txt @@ Music.Clef.(to_symbol Tenor)]
            ~value: (Version_parameters.make ~clef: Tenor (), Rendering_parameters.make ~clef: "tenor clef" ());
          choice'
            [txt @@ Music.Clef.(to_symbol Bass)]
            ~value: (Version_parameters.make ~clef: Bass (), Rendering_parameters.make ~clef: "bass clef" ());
        ]
    )
  in
  let%lwt octave_choices =
    Choices.(
      make_radios
        ~label: "Octaviation"
        [
          choice' [txt "+1"] ~value: (Version_parameters.make ~transposition: (Music.Transposition.from_octaves 1) ());
          choice' [txt "0"] ~checked: true;
          choice' [txt "-1"] ~value: (Version_parameters.make ~transposition: (Music.Transposition.from_octaves (-1)) ());
          choice' [txt "-2"] ~value: (Version_parameters.make ~transposition: (Music.Transposition.from_octaves (-2)) ());
        ]
    )
  in
  (* A signal containing the composition of all the parameters. *)
  let parameters_signal =
    let no_parameters = (Version_parameters.none, Rendering_parameters.none) in
    S.merge
      (Pair.map2 Version_parameters.compose Rendering_parameters.compose)
      no_parameters
      [
        S.map (Option.value ~default: no_parameters % Option.join % Result.to_option) (Component.signal key_choices);
        S.map (Option.value ~default: no_parameters % Option.join % Result.to_option) (Component.signal clef_choices);
        S.map (Option.value ~default: no_parameters % Option.map (Pair.snoc Rendering_parameters.none) % Option.join % Result.to_option) (Component.signal octave_choices);
      ]
  in
  lwt {
    choice_rows = [
      Component.html key_choices;
      Component.html clef_choices;
      Component.html octave_choices;
    ];
    parameters_signal;
  }

let open_pdf_generation_dialog status_signal =
  ignore
  <$> Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "Download a PDF")
      [R.div (
        Job.show_live_status
          status_signal
          ~on_succeeded: (fun href ->
            Dom_html.window##.location##.href := Js.string (Uri.to_string href);
            [txt
              "The document generation job succeeded. You will be redirected \
                soon to: ";
            a ~a: [a_href href] [txt @@ Uri.to_string href];
            ]
          )
      )]
      ~buttons: [Button.cancel' ~return ()]

let open_ (version : Version_name.t) dialog =
  Page.open_dialog @@ fun return ->
  Page.make'
    ~title: (lwt "Download a PDF")
    [div dialog.choice_rows]
    ~buttons: [
      Button.cancel' ~return ();
      Button.download
        ~onclick: (fun () ->
          let (version_params, rendering_params) = S.value dialog.parameters_signal in
          return None;
          open_pdf_generation_dialog (
            Job.status_signal
              (NesSlug.add_suffix (NesSlug.of_string version.name) ".pdf")
              (Api.call_exn (Version Build_pdf) version.id version_params rendering_params)
          )
        )
        ();
    ]

let create_and_open id = open_ id =<< create ()
