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

type page_info = {
  title: string; (** a title for the HTML page *)
  parent_title: string; (** eg. "Tune" or "Dance" *)
  api_payload: Yojson.Safe.t; (** the major API point of this page, preloaded, as a payload to hand over to the client *)
}

let make_page_info ?(title = "") ?(parent_title = "") api_payload = {
  title;
  parent_title;
  api_payload;
}

let return_page_info ?title ?parent_title endpoint value =
  lwt_some @@ make_page_info ?title ?parent_title @@ Madge.route_result_to_yojson (Endpoints.Api.route endpoint) value

(** Given a URI and an environment, preload the API point that would be called
    by the client when loading the page. *)
(* FIXME: We are duplicating work with the client here. Some version of this
   function should or could be shared. *)
let get_page_info env uri =
  let dispatch : type a r. (a, page_info option Lwt.t, r) Endpoints.Page.t -> a = function
    | Entity ->
      (fun id ->
        let endpoint : _ Endpoints.Api.t = Entity Resource_type in
        let%lwt type_ = Controller.dispatch env endpoint id in
        return_page_info endpoint type_
      )
    | Book View ->
      (fun _in_search book_id ->
        let endpoint : _ Endpoints.Api.t = Book Get_view in
        let%lwt book = Controller.dispatch env endpoint book_id in
        return_page_info ~title: book.name ~parent_title: "Book" endpoint book
      )
    | Book Preview ->
      (fun book_id _pageno ->
        let endpoint : _ Endpoints.Api.t = Book Get_view in
        let%lwt book = Controller.dispatch env endpoint book_id in
        return_page_info ~title: book.name ~parent_title: "Book" endpoint book
      )
    | Dance View ->
      (fun _in_search dance_id ->
        let endpoint : _ Endpoints.Api.t = Dance Get_view in
        let%lwt dance = Controller.dispatch env endpoint dance_id in
        return_page_info ~title: dance.name ~parent_title: "Dance" endpoint dance
      )
    | Person View ->
      (fun _in_search person_id ->
        let endpoint : _ Endpoints.Api.t = Person Get_view in
        let%lwt person = Controller.dispatch env endpoint person_id in
        return_page_info ~title: person.name ~parent_title: "Person" endpoint person
      )
    | Version View ->
      (fun _in_search _in_set version_id ->
        let endpoint : _ Endpoints.Api.t = Version Get_view in
        let%lwt version = Controller.dispatch env endpoint version_id in
        return_page_info ~title: version.tune.name ~parent_title: "Tune" endpoint version
      )
    | Tune View ->
      (fun _in_search tune_id ->
        let endpoint : _ Endpoints.Api.t = Version Get_view_for_tune in
        let%lwt version = Controller.dispatch env endpoint tune_id in
        let title =
          match version with
          | Found version -> version.tune.name
          | Fallback tune -> tune.name
        in
        return_page_info ~title ~parent_title: "Tune" endpoint version
      )
    | Set View ->
      (fun _in_search set_id ->
        let endpoint : _ Endpoints.Api.t = Set Get_view in
        let%lwt set = Controller.dispatch env endpoint set_id in
        return_page_info ~title: set.name ~parent_title: "Set" endpoint set
      )
    | Source View ->
      (fun _in_search source_id ->
        let endpoint : _ Endpoints.Api.t = Source Get_view in
        let%lwt source = Controller.dispatch env endpoint source_id in
        return_page_info ~title: source.name ~parent_title: "Source" endpoint source
      )
    | User View ->
      (fun user_id ->
        let endpoint : _ Endpoints.Api.t = User Get_view in
        let%lwt user = Controller.dispatch env endpoint user_id in
        let title = Username.to_string user.username in
        return_page_info ~title ~parent_title: "User" endpoint user
      )
    | Group View ->
      (fun group_id ->
        let endpoint : _ Endpoints.Api.t = Group Get_view in
        let%lwt group = Controller.dispatch env endpoint group_id in
        return_page_info ~title: group.name ~parent_title: "Group" endpoint group
      )
    | endpoint -> Endpoints.Page.consume ~return: lwt_none endpoint
  in
  try%lwt
    let%lwt page_info =
      Endpoints.Page.match_ {route = Endpoints.Page.route; no_route = const lwt_none; dispatch} (Madge.Request.make ~meth: GET ~uri ~body: "")
    in
    lwt @@ Option.value page_info ~default: (make_page_info `Null)
  with
    | Madge_server.Shortcut _ ->
      Log.info (fun m -> m "Madge shortcut while getting page info; skipping.");
      lwt (make_page_info `Null)
    | exn ->
      Log.err (fun m -> m "Exception while getting page info: %s" (Printexc.to_string exn));
      lwt (make_page_info `Null)

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
  fun path query preloaded_api ->
    let {canonical_url; robots_content} = canonical_url_and_robots_content @@ Uri.make ~path ~query () in
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
      script (
        Unsafe.data @@
          spf
            {| window.addEventListener("DOMContentLoaded", () => dancelorClient.run(%s)); |}
            (
              (* NOTE: one Yojson call to serialise the output to JSON, one second one to serialise the resulting string to a JS string with escaping and all *)
              Yojson.Safe.to_string @@ `String (Yojson.Safe.to_string preloaded_api)
            )
      );
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
  let%lwt page_info = get_page_info env @@ Uri.make ~path ~query () in
  let index =
    Format.asprintf "%a" (pp ()) @@
      html
        ~a: [a_lang "en"]
        (
          head
            (title (txt @@ Endpoints.Page.full_title ~title: page_info.title ~parent: page_info.parent_title))
            (make_index_head path query page_info.api_payload)
        )
        (
          body ~a: [a_class ["placeholder-glow"]] [
            header env;
            div ~a: [a_id Main_page_ids.main_container_id] [
              div ~a: [a_class ["container-md"]] [
                txt @@
                  spf
                    "Dancelor is loading%s%s..."
                    (
                      match page_info.parent_title with
                      | "" -> ""
                      | parent -> spf " the %s" (String.lowercase_ascii parent)
                    )
                    (
                      match page_info.title with
                      | "" -> ""
                      | title -> spf " “%s”" title
                    );
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
