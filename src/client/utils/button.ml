open Nes
open Js_of_ocaml
open Html

let make_content
    ?(label = "")
    ?label_processing
    ?icon
    ?badge
    ?(processing = S.const false)
    ()
  =
  List.concat @@
    List.filter_map
      Fun.id
      [
        Some
          [
            span
              ~a: [
                R.a_class
                  (
                    S.flip_map processing @@ function
                      | true -> ["spinner-border"; "spinner-border-sm"; (if label <> "" then "me-2" else "me-0")]
                      | false -> ["d-none"]
                  );
                a_aria "hidden" ["true"]
              ]
              [];
          ];
        (
          Option.flip_map icon @@ fun icon ->
          [
            span ~a: [R.a_class (S.map (function true -> ["d-none"] | _ -> []) processing)] [
              Icon.html icon ~classes: [(if label <> "" then "me-2" else "me-0")];
            ];
          ]
        );
        Some
          [
            R.txt
              (
                S.flip_map processing @@ function
                  | true -> Option.value ~default: label label_processing
                  | false -> label
              );
          ];
        (
          Option.flip_map badge @@ fun badge ->
          [
            span ~a: [a_class ["badge"; "text-bg-secondary"; "ms-2"; "me-n1"]] [txt badge];
          ]
        );
      ]

let make_attributes
    ?(dropdown = false)
    ?(classes = [])
    ?(disabled = S.const false)
    ?(processing = S.const false)
    ?tooltip
    ()
  =
  List.flatten
    [
      [R.a_class @@
        let classes = (if dropdown then ["dropdown-item"] else ["btn"]) @ classes in
        S.flip_map (S.l2 (||) disabled processing) @@ function
          | true -> "disabled" :: classes
          | false -> classes];
      (match tooltip with None -> [] | Some tooltip -> [a_title tooltip]);
    ]

let make
    ?label
    ?label_processing
    ?icon
    ?badge
    ?tooltip
    ?dropdown
    ?classes
    ?disabled
    ?onclick
    ?(more_a = [])
    ()
  =
  let (processing, set_processing) = React.S.create false in
  button
    ~a: (
      List.flatten
        [
          [a_button_type `Button];
          (
            match onclick with
            | None -> []
            | Some onclick ->
              [
                a_onclick @@ fun _event ->
                Lwt.async (fun () ->
                  set_processing true;
                  onclick ();%lwt
                  set_processing false;
                  lwt_unit
                );
                false
              ]
          );
          (make_attributes ?dropdown ?classes ?disabled ?tooltip ~processing ());
          more_a;
        ]
    )
    (
      make_content
        ?label
        ?label_processing
        ?icon
        ?badge
        ~processing
        ()
    )

let make_a
    ?label
    ?label_processing
    ?icon
    ?badge
    ?tooltip
    ?disabled
    ?dropdown
    ?classes
    ~href
    ?onclick
    ?(more_a = [])
    ()
  =
  a
    ~a: (
      List.flatten [
        [R.a_href href];
        (
          match onclick with
          | None -> []
          | Some onclick ->
            [
              a_onclick @@ fun _event ->
              Lwt.async (fun () -> onclick ();%lwt lwt_unit);
              false
            ]
        );
        (make_attributes ?dropdown ?classes ?disabled ?tooltip ());
        more_a
      ]
    )
    (
      make_content
        ?label
        ?label_processing
        ?icon
        ?badge
        ()
    )

let make_icon ?(classes = []) icon =
  button
    ~a: [a_button_type `Button; a_class (["btn"; "disabled"] @ classes); a_tabindex (-1)]
    [Icon.html icon]

let save ?label ?label_processing ?disabled ~onclick () =
  make
    ~label: (Option.value label ~default: "Save")
    ~label_processing: (Option.value label_processing ~default: "Saving...")
    ~icon: (Action Save)
    ~classes: ["btn-primary"]
    ?disabled
    ~onclick
    ()

let clear ~onclick () =
  make
    ~label: "Clear"
    ~label_processing: "Clearing..."
    ~icon: (Action Clear)
    ~classes: ["btn-warning"]
    ~onclick: (fun () ->
      if Dom_html.window##confirm (Js.string "Clear the editor?") |> Js.to_bool then
        onclick ()
      else
        lwt_unit
    )
    ()

let cancel ?onclick ?more_a () =
  make
    ~label: "Cancel"
    ~label_processing: "Cancelling..."
    ~icon: (Action Close_or_cancel)
    ~classes: ["btn-secondary"]
    ?onclick
    ?more_a
    ()

let cancel' ~return ?more_a () =
  cancel
    ~onclick: (fun () -> return None; lwt_unit)
    ?more_a
    ()

let close ?onclick ?more_a () =
  make
    ~label: "Close"
    ~label_processing: "Closing..."
    ~icon: (Action Close_or_cancel)
    ~classes: ["btn-secondary"]
    ?onclick
    ?more_a
    ()

let close' ~return ?more_a () =
  close
    ~onclick: (fun () -> return None; lwt_unit)
    ?more_a
    ()

let ok ?onclick ?more_a () =
  make
    ~label: "OK"
    ~label_processing: "Closing..."
    ~classes: ["btn-primary"]
    ?onclick
    ?more_a
    ()

let ok' ~return ?more_a () =
  ok
    ~onclick: (fun () -> return (Some ()); lwt_unit)
    ?more_a
    ()

let download ~onclick () =
  make
    ~label: "Download"
    ~icon: (Action Download)
    ~classes: ["btn-primary"]
    ~onclick
    ()
