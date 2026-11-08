open Nes
open Dancelor_common
open Html

let link fname =
  a ~a: [a_href @@ Uri.of_string @@ spf "https://github.com/niols/dancelor/blob/main/doc/%s.md" fname] [
    (* FIXME: hovering over the button should show a short help,
       which we can compute from the help page constructor *)
    Icon.html ~i ~a_class ~a_title (Other Help);
  ];
