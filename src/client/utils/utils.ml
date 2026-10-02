open Nes
open Dancelor_common
open Model_new
open Search_new
open Js_of_ocaml

module Any_result_new = Any_result_new
module Icon = Icon
module Alert = Alert
module Button = Button
module Toast = Toast
module Action = Action
module Documentation = Documentation
module Markdown = Markdown
module Tables = Tables

let write_to_clipboard = Clipboard.write_to_clipboard

let rec is_child_of : 'a 'b. ((#Dom.node as 'a) Js.t) -> ((#Dom.node as 'b) Js.t) -> bool = fun c p ->
  ((c :> Dom.node Js.t) = (p :> Dom.node Js.t))
  || (
    Js.Opt.case
      c##.parentNode
      (const false)
      (fun p' -> is_child_of p' p)
  )

let is_input : 'a. (#Dom.element as 'a) Js.t -> bool = fun n ->
  let tag = String.lowercase_ascii (Js.to_string n##.tagName) in
  tag = "input" || tag = "textarea"

let add_target_event_listener n ev f =
  let open Dom_html in
  ignore @@
    addEventListener
      n
      ev
      (
        handler @@ fun event ->
        Js.Opt.case event##.target (fun () -> Js._true) (f event)
      )
      Js._false (* default: run in bubbling phase *)

let quick_explorer_links links =
  let open Html in
  section ~a: [a_class ["mt-2"]] [
    txt "Quick links to:";
    ul ~a: [a_class ["bullet-list"]] (
      List.map
        (fun (text, query) ->
          let count_lwt = Search_result.total <$> Api.call_exn (Any Search) Slice.nothing query in
          li [
            a
              ~a: [a_href @@ Endpoints.Page.(href Explore) (Any_query.print query) 1]
              [txt text];
            R.txt (S.from_lwt "" (spf " (%d)" <$> count_lwt));
          ]
        )
        links
    );
  ]

let href_any_for_sharing any =
  let current = Uri.of_string (Js.to_string Dom_html.window##.location##.href) in
  let path = Endpoints.Page.(href Any) @@ Entry.id @@ Model_builder.Core.Any.to_entry any in
  Uri.to_string @@ Uri.with_query (Uri.with_path current (Uri.path path)) []

let href_any_for_sharing_new any =
  let current = Uri.of_string (Js.to_string Dom_html.window##.location##.href) in
  let path = Endpoints.Page.(href Any) @@ Any_id.to_entry_id any in
  Uri.to_string @@ Uri.with_query (Uri.with_path current (Uri.path path)) []
