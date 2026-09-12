open Nes
open Dancelor_common
open Model_new
open Search_new
open Html
open Utils

let view in_search id =
  Main_page.madge_call_or_404 (Source Get_view) id @@ fun source ->
  Page.make'
    ~parent_title: "Source"
    ~before_title: [Components.Context_links.for_search in_search (Any_id.Source id)]
    ~title: (lwt source.name)
    ~subtitles: [
      span (Formatters_new.Source.date_and_editors source);
    ]
    ~share: (Source id)
    ~actions: [
      (
        match%lwt Permission.can_update_public_new source with
        | None -> lwt_nil
        | Some _ ->
          lwt [
            Button.make_a
              ~label: "Edit"
              ~icon: (Action Edit)
              ~href: (S.const @@ Endpoints.Page.(href @@ Source Edit) id)
              ~dropdown: true
              ()
          ]
      );
      (
        match%lwt Permission.can_delete_public_new source with
        | None -> lwt_nil
        | Some _ ->
          lwt [
            Action.delete
              ~model: "source"
              ~onclick: (fun () -> Madge_client.call Endpoints.Api.(route @@ Source Delete) id)
              ();
          ]
      );
      (lwt @@ Option.map_to_list (Action.scddb Publication) source.scddb_id);
    ]
    [
      div
        ~a: [a_class ["row"]]
        [
          div ~a: [a_class ["col-12"; "col-sm"]] [
            img ~a: [a_style "width: 100%;"] ~alt: "Cover" ~src: (Endpoints.Api.(href @@ Source Cover) id) ()
          ];
          div ~a: [a_class ["col-12"; "col-sm"; "mt-4"; "mt-sm-0"]] [
            (
              match source.description with
              | Some desc -> Markdown.to_html desc
              | None -> p [txt "no description available"]
            );
            quick_explorer_links [
              ("versions from this source", Any_query.specific_only (Any_query.Version (Version_query.make_specific ~source: (Some [id]) ())));
            ];
          ];
        ];
    ]
