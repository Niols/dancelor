open Nes
open Utils
open Html

let copy_link_button id =
  Button.make
    ~icon: (Action Share)
    ~classes: ["btn-primary"]
    ~onclick: (fun _ ->
      write_to_clipboard @@ href_any_for_sharing_new id;
      Toast.open_ ~title: "Copied to clipboard" [txt "A short link to this page has been copied to your clipboard."];
      lwt_unit
    )
    ()
