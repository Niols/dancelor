open Js_of_ocaml
open Nes
open Dancelor_common
open Components
open Html
open Utils

let uri input page =
  Endpoints.Page.(href Explore) input (Option.value page ~default: 1)

let update_uri input page =
  Dom_html.window##.history##replaceState
    "fixme-the-state"
    (Js.string "")
    (Js.some @@ Js.string @@ Uri.to_string @@ uri input page)

let view query page =
  let on_page_change = ref (fun _n -> assert false) in
  let page_url = ref (fun _n -> assert false) in
  let search =
    Search.make
      ~search: Api.any_search
      ~initial_input: query
      ~initial_page: page
      ~pagination_mode: (Pagination ())
      ~on_input: (fun input -> update_uri input None)
      ~on_page_change: (fun page -> !on_page_change page)
      ~page_url: (fun page -> !page_url page)
      ()
  in
  on_page_change := (fun page -> update_uri (S.value @@ Search_bar.text @@ Search.search_bar search) (Some page));
  page_url := (fun page -> S.map (fun input -> uri input (some page)) (Search_bar.text @@ Search.search_bar search));
  Page.make'
    ~title: (lwt "Explore")
    ~on_load: (fun () -> Search_bar.focus @@ Search.search_bar search)
    [
      Search.render
        search
        ~make_result: (fun ?in_search result -> Any_result.make_result ?in_search result)
        ~attached_buttons: [
          Button.make
            ~label: "Filter"
            ~label_processing: "Filtering..."
            ~icon: (Other Filter)
            ~classes: ["btn-primary"]
            ~onclick: (fun () ->
              let search_text = S.value @@ Search_bar.text @@ Search.search_bar search in
              let%lwt query = Search_complex_filters_dialog.open_ search_text in
              Option.iter
                (fun query ->
                  let text = Any_query.print query ^ " " in
                  let bar = Search.search_bar search in
                  Search_bar.set_text bar text;
                  update_uri text None;
                  Search_bar.focus bar
                )
                query;
              lwt_unit
            )
            ();
        ]
    ]
