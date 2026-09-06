open Tyxml.Html
open Nes
open Dancelor_common
open Search_new

module Log = (val Logs.src_log @@ Logs.Src.create "server.static": Logs.LOG)

let base_url = Uri.of_string "https://dancelor.org"

let static_file_path path = Filename.concat (Config.get ()).share path

let serve_static_file path =
  let full_path = static_file_path path in
  if Sys.file_exists full_path && not (Sys.is_directory full_path) then
    Some (fun () ->
      (* Keep static files in cache for 30 days. *)
      let headers = Cohttp.Header.init_with "Cache-Control" "max-age=2592000" in
      Pair.cons Environment.Skip_session_cookie <$> Cohttp_lwt_unix.Server.respond_file ~headers ~fname: full_path ()
    )
  else
    None

let href_with_hash path =
  spf "/%s?%s" path @@ Digest.BLAKE256.(to_hex % file) @@ static_file_path path

let serve_index =
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
    let (canonical_url, robots_content) =
      (* For all pages but the explorer, we strip the query part from the canonical URL. Those pages
         should be indexed. For the explorer, all pages are self-canonical, but we distinguish on
         whether there is a `?q` argument in the query: if there isn't, then the page should be
         indexed; if there is, then it is a refined query and it shouldn't be indexed. All pages
         should be followed. *)
      (* FIXME: this matching is brittle *)
      match path with
      | "/explore" ->
        let uri = Uri.with_uri base_url ~path: (Some path) ~query: (Some query) in
        let robots = if List.mem_assoc "q" query then "noindex, follow" else "index, follow" in
          (uri, robots)
      | _ -> (Uri.with_path base_url path, "index, follow")
    in
    let index =
      Format.asprintf "%a" (pp ()) @@
        html
          ~a: [a_lang "en"]
          (
            head (title (txt "Dancelor")) [
              meta ~a: [a_charset "utf-8"] ();
              link ~rel: [`Canonical] ~href: (Uri.to_string canonical_url) ();
              meta ~a: [a_name "robots"; a_content robots_content] ();
              (* Style *)
              meta ~a: [a_name "viewport"; a_content "width=device-width, initial-scale=1, maximum-scale=1"] ();
              meta ~a: [a_name "description"; a_content "Dancelor — A community-edited database of Scottish country dance music. Search for tunes, assemble sets and books, and export to PDF, ready to print and bring to the dance."] ();
              link ~rel: [`Stylesheet] ~href: (Lazy.force fonts_css_href) ();
              link ~rel: [`Stylesheet] ~href: (Lazy.force style_css_href) ();
              (* Favicon *)
              link ~rel: [`Icon] ~a: [a_mime_type "image/png"; a_sizes (Some [(32, 32)])] ~href: (Lazy.force favicon_32x32_png_href) ();
              link ~rel: [`Icon] ~a: [a_mime_type "image/png"; a_sizes (Some [(16, 16)])] ~href: (Lazy.force favicon_16x16_png_href) ();
              link ~rel: [`Manifest] ~href: (Lazy.force site_webmanifest_href) ();
              (* Ahrefs ownership proof and analytics *)
              meta ~a: [a_name "ahrefs-site-verification"; a_content "4c418f04303adf3925d1c6bdef51b71cab26cd179ab478ecd1996cf71ce52ba4"] ();
              script ~a: [a_src "https://analytics.ahrefs.com/analytics.js"; a_user_data "key" "HmcihempNgdCWYAHGvIYsg"; a_async ()] (txt "");
              (* Dancelor *)
              script ~a: [a_script_type `Javascript; a_src (Lazy.force client_js_href)] (txt "");
            ]
          )
          (
            body
              ~a: [a_class ["placeholder-glow"]]
              [
                script ~a: [a_src (Lazy.force bootstrap_bundle_min_js_href)] (txt "");
              ]
          )
    in
    let headers = Cohttp.Header.of_list [("Content-Type", "text/html")] in
    Cohttp_lwt_unix.Server.respond_string ~headers ~status: `OK ~body: index ()

let static_pages = List.map Uri.of_string ["/"; "/explore"]

let serve_sitemap env =
  let%lwt anys = Search_result.items <$> Controller.Any.search env Slice.everything (Any_query.empty) in
  let urls = static_pages @ List.map (Endpoints.Page.href_any_full_new % Model_new.Any_row.to_id) anys in
  let urls = List.map (fun url -> Uri.with_path base_url (Uri.path url)) urls in
  let%lwt sitemap =
    let buf = Buffer.create 10240 in
    let fmt = Format.formatter_of_buffer buf in
    fpf fmt {|<?xml version="1.0" encoding="UTF-8"?>|};
    fpf fmt {|<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">|};
    (* FIXME: Probably that the update frequency should depend on what we're talking
       about. The explore page might change very often but the items themselves
       should change pretty rarely. For now, we put weekly everywhere. *)
    List.iter (fpf fmt {|<url><loc>%s</loc><changefreq>weekly</changefreq></url>|} % Uri.to_string) urls;
    fpf fmt {|</urlset>|};
    Format.pp_print_flush fmt ();
    lwt @@ Buffer.contents buf
  in
  let headers =
    Cohttp.Header.of_list [
      ("Content-Type", "application/xml");
      ("Cache-Control", "max-age=3600");
    ]
  in
  Pair.cons Environment.Skip_session_cookie
  <$> Cohttp_lwt_unix.Server.respond_string ~headers ~status: `OK ~body: sitemap ()

let serve_robots_txt () =
  let robots_txt = spf "Sitemap: %s/sitemap.xml\nUser-agent: *\nAllow: /\n" (Uri.to_string base_url) in
  let headers =
    Cohttp.Header.of_list [
      ("Content-Type", "text/plain");
      ("Cache-Control", "max-age=3600");
    ]
  in
  Pair.cons Environment.Skip_session_cookie
  <$> Cohttp_lwt_unix.Server.respond_string ~headers ~status: `OK ~body: robots_txt ()

let serve env path query =
  Log.debug (fun m -> m "Looking to serve %S" path);
  match serve_static_file path with
  | Some serve_static_file ->
    (
      let path = String.ltrim ~chars: ['/'] path in
      Metrics.increment_http_requests_count (`Static path);
      Log.debug (fun m -> m "Serving static file: <share>/%s" path);
      serve_static_file ()
    )
  | None ->
    if path = "/sitemap.xml" then
      (
        Metrics.increment_http_requests_count (`Static "sitemap.xml");
        Log.debug (fun m -> m "Generating and serving sitemap.xml");
        serve_sitemap env
      )
    else if path = "/robots.txt" then
      (
        Metrics.increment_http_requests_count (`Static "robots.txt");
        Log.debug (fun m -> m "Serving robots.txt");
        serve_robots_txt ()
      )
    else
      (
        Metrics.increment_http_requests_count `Main_file;
        Log.debug (fun m -> m "Serving main file.");
        Pair.cons Environment.Add_session_cookie <$> serve_index path query
      )
