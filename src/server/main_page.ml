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
  let madge_match_apply_all : canonical_url_and_robots_content option Endpoints.Page.wrapped' list -> (unit -> canonical_url_and_robots_content option) option =
    List.find_map @@ fun (Endpoints.Page.W' endpoint) ->
    Madge.apply' (Endpoints.Page.route endpoint) (fun () -> dispatch endpoint) (Madge.Request.make ~meth: GET ~uri ~body: "")
  in
  match madge_match_apply_all @@ Endpoints.Page.all' () with
  | None -> default_canonical_url_and_robots_content uri
  | Some canonical_url_and_robots_content ->
    match canonical_url_and_robots_content () with
    | None -> default_canonical_url_and_robots_content uri
    | Some canonical_url_and_robots_content -> canonical_url_and_robots_content

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
    let {canonical_url; robots_content} = canonical_url_and_robots_content (Uri.make ~path ~query ()) in
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
              script ~a: [a_script_type `Javascript] (
                txt {| window.onload = dancelorClient.run; |}
              );
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

let serve _env path query =
  Metrics.increment_http_requests_count `Main_file;
  Log.debug (fun m -> m "Serving main file.");
  Pair.cons Environment.Add_session_cookie <$> serve_index path query
