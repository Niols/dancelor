open Nes
open Dancelor_common
open Model_new
open Model_builder.Core
open Html
open Utils
open Components

(* REVIEW: This is close to `Version_download_dialog.t`; there is room for
   factorisation here. *)
type t = {
  choice_rows: Html_types.div elt list;
  download_type: [`Book_pdf | `Sets_zip] React.signal;
  parameters_signal: (Book_parameters.t * Rendering_parameters.t) React.signal;
}

let lift_set_parameters every_set =
  Book_parameters.make ~every_set ()

let create () =
  let%lwt set_dialog = Set_download_dialog.create () in
  let%lwt booklet_choices =
    Choices.(
      make_radios
        ~label: "Mode"
        [
          choice [txt "Normal"] ~checked: true ~value: (`Book_pdf Book_parameters.none);
          choice [txt "Simple"] ~value: (`Book_pdf (Book_parameters.make ~simple: true ()));
          choice [txt "Separate (ZIP)"] ~value: `Sets_zip;
        ]
    )
  in
  lwt {
    choice_rows = (
      set_dialog.choice_rows @ [
        Component.html booklet_choices;
      ]
    );
    download_type =
    S.map
      (function
        | Ok`Book_pdf _ | Error _ -> `Book_pdf
        | Ok `Sets_zip -> `Sets_zip
      )
      (Component.signal booklet_choices);
    parameters_signal =
    S.merge
      (Pair.map2 Book_parameters.compose Rendering_parameters.compose)
      (Book_parameters.none, Rendering_parameters.none)
      [
        S.map (Pair.map_fst lift_set_parameters) set_dialog.parameters_signal;
        S.map
          (function
            | Ok`Book_pdf params -> (params, Rendering_parameters.none)
            | Ok `Sets_zip | Error _ -> (Book_parameters.none, Rendering_parameters.none)
          )
          (Component.signal booklet_choices);
      ]
  }

(* REVIEW: This is extremely close to `Version_download_dialog.render` (apart for
   one line and one type, really); there is room for factorisation here. *)
let open_ (book : Book_view.t) dialog =
  Page.open_dialog @@ fun return ->
  Page.make'
    ~title: (lwt "Download a PDF")
    [div dialog.choice_rows]
    ~buttons: [
      Button.cancel' ~return ();
      Button.download
        ~onclick: (fun () ->
          let (book_params, rendering_params) = S.value dialog.parameters_signal in
          let (endpoint, extension) =
            match S.value dialog.download_type with
            | `Book_pdf -> Endpoints.Book.Build_pdf, ".pdf"
            | `Sets_zip -> Endpoints.Book.Build_zip, ".zip"
          in
          return None;
          Version_download_dialog.open_pdf_generation_dialog (
            Job.status_signal_non_copyrighted
              (NesSlug.add_suffix (NesSlug.of_string book.name) extension)
              (Api.call_exn (Book endpoint) book.id book_params rendering_params)
          )
        )
        ();
    ]

let create_and_open book = open_ book =<< create ()
