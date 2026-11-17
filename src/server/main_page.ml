open Tyxml.Html
open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.main-page": Logs.LOG)

let href_with_hash path =
  spf "/%s?%s" path @@ Digest.BLAKE256.(to_hex % file) @@ Static.file_path path

type canonical_url_and_robots_content = {
  canonical_url: Uri.t;
  robots_content: string;
}

let no_query_canonical_url uri = Uri.with_path Static.base_url (Uri.path uri)
let full_canonical_url uri = Uri.with_uri Static.base_url ~path: (Some (Uri.path uri)) ~query: (Some (Uri.query uri))

let default_canonical_url_and_robots_content uri = {
  canonical_url = no_query_canonical_url uri;
  robots_content = "index, follow";
}

(** For all pages but the explorer, we strip the query part from the canonical
    URL. Those pages should be indexed. For the explorer, all pages are
    self-canonical, but we distinguish on whether there is a `?q` argument in
    the query: if there isn't, then the page should be indexed; if there is,
    then it is a refined query and it shouldn't be indexed. All pages should be
    followed. *)
let canonical_url_and_robots_content uri =
  let dispatch : type a r. (a, canonical_url_and_robots_content option, r) Endpoints.Page.t -> a = function
    | Explore ->
      (fun query _page ->
        Some {
          canonical_url = full_canonical_url uri;
          robots_content = if query = "" then "index, follow" else "noindex, follow";
        }
      )
    | page -> Endpoints.Page.consume page ~return: None
  in
  match Endpoints.Page.match_ {route = Endpoints.Page.route; no_route = const None; dispatch} (Madge.Request.make ~meth: GET ~uri ~body: "") with
  | None -> default_canonical_url_and_robots_content uri
  | Some canonical_url_and_robots_content -> canonical_url_and_robots_content

let make_index_head =
  (* NOTE: We add the hash of static files to their URL to invalidate
     cache (in particular `client.js`). Otherwise, we cache them for
     as long as possible. *)
  let fonts_css_href = Lazy.from_fun @@ fun () -> href_with_hash "fonts.css" in
  let style_css_href = Lazy.from_fun @@ fun () -> href_with_hash "style.css" in
  let favicon_16x16_png_href = Lazy.from_fun @@ fun () -> href_with_hash "favicon-16x16.png" in
  let favicon_32x32_png_href = Lazy.from_fun @@ fun () -> href_with_hash "favicon-32x32.png" in
  let site_webmanifest_href = Lazy.from_fun @@ fun () -> href_with_hash "site.webmanifest" in
  let client_js_href = Lazy.from_fun @@ fun () -> href_with_hash "client.js" in
  let bootstrap_bundle_min_js_href = Lazy.from_fun @@ fun () -> href_with_hash "bootstrap.bundle.min.js" in
  fun path query ->
    let {canonical_url; robots_content} = canonical_url_and_robots_content (Uri.make ~path ~query ()) in
    [
      meta ~a: [a_charset "utf-8"] ();
      link ~rel: [`Canonical] ~href: (Uri.to_string canonical_url) ();
      meta ~a: [a_name "robots"; a_content robots_content] ();
      (* Style *)
      meta ~a: [a_name "viewport"; a_content "width=device-width, initial-scale=1, maximum-scale=1"] ();
      meta ~a: [a_name "description"; a_content "Dancelor — A community-edited database of Scottish country dance music. Search for tunes, assemble sets and books, and export to PDF, ready to print and bring to the dance."] ();
      link ~rel: [`Stylesheet] ~href: (Lazy.force fonts_css_href) ();
      link ~rel: [`Stylesheet] ~href: (Lazy.force style_css_href) ();
      script ~a: [a_defer (); a_src (Lazy.force bootstrap_bundle_min_js_href)] (txt "");
      (* Favicon *)
      link ~rel: [`Icon] ~a: [a_mime_type "image/png"; a_sizes (Some [(32, 32)])] ~href: (Lazy.force favicon_32x32_png_href) ();
      link ~rel: [`Icon] ~a: [a_mime_type "image/png"; a_sizes (Some [(16, 16)])] ~href: (Lazy.force favicon_16x16_png_href) ();
      link ~rel: [`Manifest] ~href: (Lazy.force site_webmanifest_href) ();
      (* Ahrefs ownership proof and analytics *)
      meta ~a: [a_name "ahrefs-site-verification"; a_content "4c418f04303adf3925d1c6bdef51b71cab26cd179ab478ecd1996cf71ce52ba4"] ();
      script ~a: [a_src "https://analytics.ahrefs.com/analytics.js"; a_user_data "key" "HmcihempNgdCWYAHGvIYsg"; a_async ()] (txt "");
      (* Dancelor *)
      script ~a: [a_defer (); a_src (Lazy.force client_js_href)] (txt "");
      script (Unsafe.data {| window.addEventListener("DOMContentLoaded", () => dancelorClient.run()); |});
    ]

let nav_item_explore =
  li
    ~a: [a_class ["nav-item"; "dropdown"]]
    [
      Static_button.make
        ~label: "Explore"
        ~classes: ["text-white"; "dropdown-toggle"]
        ~more_a: [a_user_data "bs-toggle" "dropdown"; a_aria "expanded" ["false"]]
        ();
      ul
        ~a: [a_class ["dropdown-menu"]]
        (
          [li [Static_button.make_a ~label: "All" ~href: (Endpoints.Page.(href Explore) "" 1) ~dropdown: true ()];
          li [hr ~a: [a_class ["dropdown-divider"]] ()];
          ] @
            List.map
              (fun (icon, key, label) ->
                let href = Endpoints.Page.(href Explore) (spf "type:%s" key) 1 in
                li [Static_button.make_a ~label ~icon: (Entity icon) ~href ~dropdown: true ()]
              )
              [
                (Icon.Person, "person", "Persons");
                (Icon.Dance, "dance", "Dances");
                (Icon.Source, "source", "Sources");
                (Icon.Tune, "tune", "Tunes");
                (Icon.Version, "version", "Versions");
                (Icon.Set, "set", "Sets");
                (Icon.Book, "book", "Books");
              ]
        );
    ]

let nav_item_create env =
  match Environment.actor env with
  | Signed_in _ ->
    [
      li
        ~a: [a_class ["nav-item"; "dropdown"]]
        [
          Static_button.make
            ~label: "Add"
            ~classes: ["text-white"; "dropdown-toggle"]
            ~more_a: [a_user_data "bs-toggle" "dropdown"; a_aria "expanded" ["false"]]
            ();
          ul
            ~a: [a_class ["dropdown-menu"]]
            (
              let open Endpoints.Page in
              List.map
                (fun (icon, href, label) ->
                  li [Static_button.make_a ~label ~icon: (Entity icon) ~href ~dropdown: true ()]
                )
                [
                  (Icon.Person, href (Person Add), "Person");
                  (Icon.Dance, href (Dance Add), "Dance");
                  (Icon.Source, href (Source Add), "Source");
                  (Icon.Tune, href (Tune Add), "Tune");
                  (Icon.Version, href (Version Add) None, "Version");
                  (Icon.Set, href (Set Add), "Set");
                  (Icon.Book, href (Book Add), "Book");
                ]
            );
        ]
    ]
  | _ -> []

let header env =
  nav
    ~a: [a_class ["bg-primary"; "navbar"; "navbar-expand-sm"; "navbar-dark"; "mb-2"]]
    [
      div
        ~a: [a_class ["container-md"]]
        [
          a
            ~a: [a_class ["navbar-brand"; "my-n2"; "py-0"; "flex-fill"]; a_href "/"]
            [
              img ~a: [a_height 60] ~src: "/logo.svg" ~alt: "Dancelor" ();
            ];
          div ~a: [a_id @@ Main_page_ids.quick_search_button_container_id `Mobile] [
            Static_button.make
              ~icon: (Action Search)
              ~classes: ["btn-light"; "me-2"; "d-block"; "d-sm-none"; "disabled"]
              ();
          ];
          button
            ~a: [a_class ["navbar-toggler"]; a_button_type `Button; a_user_data "bs-toggle" "collapse"; a_user_data "bs-target" "#the-navigation"; a_aria "controls" ["the-navigation"]; a_aria "expanded" ["false"]; a_aria "label" ["Toggle navigation"]]
            [
              span ~a: [a_class ["navbar-toggler-icon"]] [];
            ];
          div
            ~a: [a_class ["collapse"; "navbar-collapse"]; a_id "the-navigation"]
            [
              ul
                ~a: [a_class ["navbar-nav"; "ms-auto"]]
                (
                  List.flatten [
                    [nav_item_explore];
                    nav_item_create env;
                    [li ~a: [a_id Main_page_ids.actor_header_container_id] []];
                  ]
                );
            ];
          div ~a: [a_id @@ Main_page_ids.quick_search_button_container_id `Desktop] [
            Static_button.make
              ~label: "Search"
              ~icon: (Action Search)
              ~badge: "/"
              ~classes: ["btn-light"; "ms-2"; "d-none"; "d-sm-block"; "disabled"]
              ();
          ];
        ];
    ]

let footer =
  nav
    ~a: [a_class ["bg-primary"; "navbar"; "navbar-expand-sm"; "navbar-dark"; "mt-4"]]
    [
      div
        ~a: [a_class ["container-md"; "d-flex"; "flex-column"; "flex-sm-row"]]
        [
          a ~a: [a_class ["text-light"; "my-1"]; a_href "/"] [txt "Dancelor"];
          a
            ~a: [
              a_class ["icon-link"; "text-light"; "my-1"];
              a_href "https://github.com/niols/dancelor";
              a_target "_blank";
            ]
            [
              Icon.html ~i ~a_class ~a_title (Other GitHub);
              txt "niols/dancelor";
            ];
          div ~a: [a_id Main_page_ids.issue_report_button_container_id] [
            Static_button.make
              ~label: "Report an issue"
              ~icon: (Other Bug)
              ~classes: ["btn-light"; "my-1"; "disabled"]
              ()
          ];
        ];
    ]

let serve_index env path query =
  let index =
    Format.asprintf "%a" (pp ()) @@
      html
        ~a: [a_lang "en"]
        (head (title (txt "Dancelor")) (make_index_head path query))
        (
          body ~a: [a_class ["placeholder-glow"]] [
            header env;
            div ~a: [a_id Main_page_ids.main_container_id] [
              div ~a: [a_class ["container-md"]] [
                txt "Dancelor is loading...";
              ];
            ];
            footer;
          ]
        )
  in
  let headers = Cohttp.Header.of_list [("Content-Type", "text/html")] in
  Cohttp_lwt_unix.Server.respond_string ~headers ~status: `OK ~body: index ()

let serve env path query =
  Metrics.increment_http_requests_count `Main_file;
  Log.debug (fun m -> m "Serving main file.");
  Pair.cons Environment.Add_session_cookie <$> serve_index env path query
