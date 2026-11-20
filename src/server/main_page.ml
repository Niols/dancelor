open Tyxml.Html
open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.main-page": Logs.LOG)

let href_with_hash ?(absolute = false) path =
  spf "%s/%s?%s" (if absolute then Uri.to_string Static.base_url else "") path (Digest.BLAKE256.(to_hex % file) @@ Static.file_path path)

type page_info = {
  title: string; (** a title for the HTML page *)
  parent_title: string; (** eg. "Tune" or "Dance" *)
  description: string; (** a description for the HTML page *)
  api_payload: Yojson.Safe.t; (** the major API point of this page, preloaded, as a payload to hand over to the client *)
  canonical_url: Uri.t; (** canonical URL for this page *)
  robots_content: string; (** content of the robots meta for this page *)
}

let make_canonical_url endpoint =
  Madge.with_request (Endpoints.Page.route endpoint) (fun (module _) request ->
    let uri = Madge.Request.uri request in
    Uri.with_uri Static.base_url ~path: (some @@ Uri.path uri) ~query: (some @@ Uri.query uri)
  )

let no_query_canonical_url uri = Uri.with_path Static.base_url (Uri.path uri)

let make_page_info ?(title = "") ?(parent_title = "") ~description ?(robots_content = "index, follow") ~canonical_url api_payload =
  {title; parent_title; description; api_payload; canonical_url; robots_content}

let default_description = "Dancelor — A community-edited database of Scottish country dance music. Search for tunes, assemble sets and books, and export to PDF, ready to print and bring to the dance."

let no_page_info uri = make_page_info ~description: default_description ~canonical_url: (no_query_canonical_url uri) `Null

let return_page_info ?title ?parent_title ~description ~canonical_url endpoint value =
  lwt_some @@
  make_page_info ?title ?parent_title ~description ~canonical_url @@
  Madge.route_result_to_yojson (Endpoints.Api.route endpoint) value

(* FIXME: We are duplicating work with the client and the PDF generator here. *)

let list to_string items = String.concat ", " ~last: " and " (List.map to_string items)

let book_description (book : Book_view.t) =
  let published =
    match book.date with
    | None -> ""
    | Some date -> spf ", published %s" (Partial_date.to_pretty_string ~at: true date)
  in
  spf "Book by %s%s." (list Person_name.name book.authors) published

let person_description (_person : Person_view.t) =
  "Person." (* FIXME: This is not a lot :p *)

let dance_description (dance : Dance_view.t) =
  let kind_devisers =
    let kind = Kind.Dance.to_pretty_string dance.kind in
    match dance.devisers with
    | [] -> kind
    | [deviser] when deviser.name = "Traditional" -> spf "Traditional %s" kind
    | devisers -> spf "%s by %s" kind (list Person_name.name devisers)
  in
  spf "%s." kind_devisers

let tune_description (tune : Tune_view.t) =
  let kind_composers =
    let kind = Kind.Base.to_long_string tune.kind in
    match tune.composers with
    | [] -> kind ~capitalised: true
    | [composer] when composer.name = "Traditional" -> spf "Traditional %s" (kind ~capitalised: false)
    | composers -> spf "%s by %s" (kind ~capitalised: true) (list Person_name_with_details.name composers)
  in
  spf "%s." kind_composers

let version_description (version : Version_view.t) =
  let key = Music.Key.to_pretty_string version.key in
  let content =
    match version.content with
    | No_content -> "No content"
    | Monolithic {bars; structure} ->
      let structure = NEString.to_string @@ Version_content.Structure.to_string structure in
      spf "Monolithic %d-bar %s version in %s" bars structure key
    | Destructured {default_structure = _} -> spf "Destructured version in %s" key
  in
  let arranger =
    match version.arrangers with
    | [] -> ""
    | arrangers -> spf ", arranged by %s" (list Person_name.name arrangers)
  in
  let disambiguation =
    match version.disambiguation with
    | None -> ""
    | Some disambiguation -> spf " (%s)" disambiguation
  in
  spf "%s %s%s%s." (tune_description version.tune) content arranger disambiguation

let set_description (set : Set_view.t) =
  let kind_conceptors =
    let kind = Kind.Dance.to_pretty_string set.kind in
    match set.conceptors with
    | [] -> kind
    | conceptors -> spf "%s by %s" kind (list Person_name.name conceptors)
  in
  let tunes =
    match set.content with
    | [] -> " (empty)"
    | content -> spf ", featuring %s" (list (Tune_row.name % Version_row.tune % fst) content)
  in
  spf "%s%s." kind_conceptors tunes

let source_description (source : Source_view.t) =
  let published =
    match source.date with
    | None -> ""
    | Some date -> spf ", published %s" (Partial_date.to_pretty_string ~at: true date)
  in
  spf "Source by %s%s." (list Person_name.name source.editors) published

let user_description (_user : User_view.t) =
  "User." (* FIXME *)

let group_description (group : Group_view.t) =
  match group.members with
  | [] -> "Empty group"
  | members -> spf "Group containing %s" (list (Username.to_string % User_row.username) members)

(** Given a URI and an environment, preload the API point that would be called
    by the client when loading the page. *)
(* FIXME: We are duplicating work with the client here. Some version of this
   function should or could be shared. *)
let get_page_info env uri =
  let dispatch : type a r. (a, page_info option Lwt.t, r) Endpoints.Page.t -> a = function
    | Index ->
      let canonical_url = make_canonical_url Index in
      lwt_some @@ make_page_info ~description: default_description ~canonical_url `Null
    | Entity ->
      (fun id ->
        (* FIXME: run the whole redirection directly in there, returning the
           right type to the client, the right canonical URL, etc. *)
        let canonical_url = make_canonical_url Entity id in
        let endpoint : _ Endpoints.Api.t = Entity Resource_type in
        let%lwt type_ = Controller.dispatch env endpoint id in
        return_page_info ~description: default_description ~canonical_url endpoint type_
      )
    | Book View ->
      (fun _in_search book_id ->
        let canonical_url = make_canonical_url (Book View) None book_id in
        let endpoint : _ Endpoints.Api.t = Book Get_view in
        let%lwt book = Controller.dispatch env endpoint book_id in
        let description = book_description book in
        return_page_info ~title: book.name ~parent_title: "Book" ~description ~canonical_url endpoint book
      )
    | Book Preview ->
      (fun book_id pageno ->
        let canonical_url = make_canonical_url (Book Preview) book_id pageno in
        let endpoint : _ Endpoints.Api.t = Book Get_view in
        let%lwt book = Controller.dispatch env endpoint book_id in
        let description = spf "Preview page #%d. %s" pageno (book_description book) in
        return_page_info ~title: book.name ~parent_title: "Book" ~description ~canonical_url endpoint book
      )
    | Dance View ->
      (fun _in_search dance_id ->
        let canonical_url = make_canonical_url (Dance View) None dance_id in
        let endpoint : _ Endpoints.Api.t = Dance Get_view in
        let%lwt dance = Controller.dispatch env endpoint dance_id in
        let description = dance_description dance in
        return_page_info ~title: dance.name ~parent_title: "Dance" ~description ~canonical_url endpoint dance
      )
    | Person View ->
      (fun _in_search person_id ->
        let canonical_url = make_canonical_url (Person View) None person_id in
        let endpoint : _ Endpoints.Api.t = Person Get_view in
        let%lwt person = Controller.dispatch env endpoint person_id in
        let description = person_description person in
        return_page_info ~title: person.name ~parent_title: "Person" ~description ~canonical_url endpoint person
      )
    | Version View ->
      (fun _in_search _in_set version_id ->
        let canonical_url = make_canonical_url (Version View) None None version_id in
        let endpoint : _ Endpoints.Api.t = Version Get_view in
        let%lwt version = Controller.dispatch env endpoint version_id in
        let description = version_description version in
        return_page_info ~title: version.tune.name ~parent_title: "Tune" ~description ~canonical_url endpoint version
      )
    | Tune View ->
      (fun _in_search tune_id ->
        let canonical_url = make_canonical_url (Tune View) None tune_id in
        let endpoint : _ Endpoints.Api.t = Version Get_view_for_tune in
        let%lwt version = Controller.dispatch env endpoint tune_id in
        let (title, description) =
          match version with
          | Found version -> (version.tune.name, version_description version)
          | Fallback tune -> (tune.name, tune_description tune)
        in
        return_page_info ~title ~parent_title: "Tune" ~description ~canonical_url endpoint version
      )
    | Set View ->
      (fun _in_search set_id ->
        let canonical_url = make_canonical_url (Set View) None set_id in
        let endpoint : _ Endpoints.Api.t = Set Get_view in
        let%lwt set = Controller.dispatch env endpoint set_id in
        let description = set_description set in
        return_page_info ~title: set.name ~parent_title: "Set" ~description ~canonical_url endpoint set
      )
    | Source View ->
      (fun _in_search source_id ->
        let canonical_url = make_canonical_url (Source View) None source_id in
        let endpoint : _ Endpoints.Api.t = Source Get_view in
        let%lwt source = Controller.dispatch env endpoint source_id in
        let description = source_description source in
        return_page_info ~title: source.name ~parent_title: "Source" ~description ~canonical_url endpoint source
      )
    | User View ->
      (fun user_id ->
        let canonical_url = make_canonical_url (User View) user_id in
        let endpoint : _ Endpoints.Api.t = User Get_view in
        let%lwt user = Controller.dispatch env endpoint user_id in
        let title = Username.to_string user.username in
        let description = user_description user in
        return_page_info ~title ~parent_title: "User" ~description ~canonical_url endpoint user
      )
    | Group View ->
      (fun group_id ->
        let canonical_url = make_canonical_url (Group View) group_id in
        let endpoint : _ Endpoints.Api.t = Group Get_view in
        let%lwt group = Controller.dispatch env endpoint group_id in
        let description = group_description group in
        return_page_info ~title: group.name ~parent_title: "Group" ~description ~canonical_url endpoint group
      )
    | endpoint -> Endpoints.Page.consume ~return: lwt_none endpoint
  in
  try%lwt
    let%lwt page_info =
      Endpoints.Page.match_ {route = Endpoints.Page.route; no_route = const lwt_none; dispatch} (Madge.Request.make ~meth: GET ~uri ~body: "")
    in
    lwt @@ Option.value page_info ~default: (no_page_info uri)
  with
    | Madge_server.Shortcut _ ->
      Log.info (fun m -> m "Madge shortcut while getting page info; skipping.");
      lwt (no_page_info uri)
    | exn ->
      Log.err (fun m -> m "Exception while getting page info: %s" (Printexc.to_string exn));
      lwt (no_page_info uri)

let make_index_head =
  (* NOTE: We add the hash of static files to their URL to invalidate
     cache (in particular `client.js`). Otherwise, we cache them for
     as long as possible. *)
  let fonts_css_href = Lazy.from_fun @@ fun () -> href_with_hash "fonts.css" in
  let style_css_href = Lazy.from_fun @@ fun () -> href_with_hash "style.css" in
  let logo_1200x630_png_href_absolute = Lazy.from_fun @@ fun () -> href_with_hash ~absolute: true "logo-1200x630.png" in
  let favicon_svg_href = Lazy.from_fun @@ fun () -> href_with_hash "favicon.svg" in
  let favicon_16x16_png_href = Lazy.from_fun @@ fun () -> href_with_hash "favicon-16x16.png" in
  let favicon_32x32_png_href = Lazy.from_fun @@ fun () -> href_with_hash "favicon-32x32.png" in
  let apple_touch_icon_png_href = Lazy.from_fun @@ fun () -> href_with_hash "apple-touch-icon.png" in
  let site_webmanifest_href = Lazy.from_fun @@ fun () -> href_with_hash "site.webmanifest" in
  let client_js_href = Lazy.from_fun @@ fun () -> href_with_hash "client.js" in
  let bootstrap_bundle_min_js_href = Lazy.from_fun @@ fun () -> href_with_hash "bootstrap.bundle.min.js" in
  fun page_info ->
    [
      meta ~a: [a_charset "utf-8"] ();
      link ~rel: [`Canonical] ~href: (Uri.to_string page_info.canonical_url) ();
      meta ~a: [a_name "robots"; a_content page_info.robots_content] ();
      meta ~a: [a_name "description"; a_content page_info.description] ();
      (* Favicon *)
      link ~rel: [`Icon] ~a: [a_mime_type "image/svg+xml"] ~href: (Lazy.force favicon_svg_href) ();
      link ~rel: [`Icon] ~a: [a_mime_type "image/png"; a_sizes (Some [(32, 32)])] ~href: (Lazy.force favicon_32x32_png_href) ();
      link ~rel: [`Icon] ~a: [a_mime_type "image/png"; a_sizes (Some [(16, 16)])] ~href: (Lazy.force favicon_16x16_png_href) ();
      link ~rel: [`Other "apple-touch-icon"] ~a: [a_mime_type "image/png"] ~href: (Lazy.force apple_touch_icon_png_href) ();
      link ~rel: [`Manifest] ~href: (Lazy.force site_webmanifest_href) ();
      (* OpenGraph *)
      meta ~a: [a_property "og:type"; a_content "website"] ();
      meta ~a: [a_property "og:url"; a_content (Uri.to_string page_info.canonical_url)] ();
      meta ~a: [a_property "og:site_name"; a_content "Dancelor"] ();
      meta ~a: [a_property "og:title"; a_content (Endpoints.Page.full_title_no_dancelor ~title: page_info.title ~parent: page_info.parent_title)] ();
      meta ~a: [a_property "og:description"; a_content page_info.description] ();
      meta ~a: [a_property "og:image"; a_content (Lazy.force logo_1200x630_png_href_absolute)] ();
      meta ~a: [a_property "og:image:type"; a_content "image/png"] ();
      meta ~a: [a_property "og:image:width"; a_content "1200"] ();
      meta ~a: [a_property "og:image:height"; a_content "630"] ();
      meta ~a: [a_property "og:image:alt"; a_content "Dancelor logo: white lettering on a red background, with a faint treble clef"] ();
      meta ~a: [a_name "twitter:card"; a_content "summary_large_image"] ();
      (* Style *)
      meta ~a: [a_name "viewport"; a_content "width=device-width, initial-scale=1, maximum-scale=1"] ();
      link ~rel: [`Stylesheet] ~href: (Lazy.force fonts_css_href) ();
      link ~rel: [`Stylesheet] ~href: (Lazy.force style_css_href) ();
      script ~a: [a_defer (); a_src (Lazy.force bootstrap_bundle_min_js_href)] (txt "");
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
              Yojson.Safe.to_string @@ `String (Yojson.Safe.to_string page_info.api_payload)
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
            (make_index_head page_info)
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
