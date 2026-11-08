open Nes
open Tyxml.Html

let make_content
    ?(label = "")
    ?icon
    ?badge
    ()
  =
  List.concat @@
    List.filter_map
      Fun.id
      [
        (
          Option.flip_map icon @@ fun icon ->
          [
            span [
              Icon.html
                ~i
                ~a_class
                ~a_title
                icon
                ~classes: [(if label <> "" then "me-2" else "me-0")]
            ]
          ]
        );
        Some [txt label];
        (
          Option.flip_map badge @@ fun badge ->
          [span ~a: [a_class ["badge"; "text-bg-secondary"; "ms-2"; "me-n1"]] [txt badge]]
        );
      ]

let make_attributes
    ?(dropdown = false)
    ?(classes = [])
    ?tooltip
    ()
  =
  List.flatten
    [
      [a_class @@ (if dropdown then ["dropdown-item"] else ["btn"]) @ classes];
      (match tooltip with None -> [] | Some tooltip -> [a_title tooltip]);
    ]

let make
    ?label
    ?icon
    ?badge
    ?tooltip
    ?dropdown
    ?classes
    ?(more_a = [])
    ()
  =
  button
    ~a: (
      List.flatten
        [
          [a_button_type `Button];
          (make_attributes ?dropdown ?classes ?tooltip ());
          more_a;
        ]
    )
    (make_content ?label ?icon ?badge ())

let make_a
    ?label
    ?icon
    ?badge
    ?tooltip
    ?dropdown
    ?classes
    ~href
    ?(more_a = [])
    ()
  =
  a
    ~a: (
      List.flatten [
        [a_href @@ Uri.to_string href];
        (make_attributes ?dropdown ?classes ?tooltip ());
        more_a
      ]
    )
    (make_content ?label ?icon ?badge ())

let make_icon ?(classes = []) icon =
  button
    ~a: [a_button_type `Button; a_class (["btn"; "disabled"] @ classes); a_tabindex (-1)]
    [Icon.html ~i ~a_class ~a_title icon]
