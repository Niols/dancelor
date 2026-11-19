open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.static": Logs.LOG)

let base_url = Uri.of_string "https://dancelor.org"

let file_path path = Filename.concat (Config.get ()).share path

let serve_static_file path =
  let full_path = file_path path in
  if Sys.file_exists full_path && not (Sys.is_directory full_path) then
    Some (fun () ->
      (* Keep static files in cache for 30 days. *)
      let headers = Cohttp.Header.init_with "Cache-Control" "max-age=2592000" in
      Pair.cons Environment.Skip_session_cookie <$> Cohttp_lwt_unix.Server.respond_file ~headers ~fname: full_path ()
    )
  else
    None

let static_pages = List.map Uri.of_string ["/"; "/explore"]

let serve_sitemap env =
  let%lwt resources = Search_result.items <$> Controller.Entity.search_resources env Slice.everything (Entity_query.empty) in
  let urls = static_pages @ List.map (Endpoints.Page.href_entity_full % Resource_row.to_id) resources in
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

let serve env path =
  Log.debug (fun m -> m "Looking to serve %S" path);
  match serve_static_file path with
  | Some serve_static_file ->
    (
      let path = String.ltrim ~chars: ['/'] path in
      Metrics.increment_http_requests_count (`Static path);
      Log.debug (fun m -> m "Serving static file: <share>/%s" path);
      Some (serve_static_file ())
    )
  | None ->
    if path = "/sitemap.xml" then
      (
        Metrics.increment_http_requests_count (`Static "sitemap.xml");
        Log.debug (fun m -> m "Generating and serving sitemap.xml");
        Some (serve_sitemap env)
      )
    else if path = "/robots.txt" then
      (
        Metrics.increment_http_requests_count (`Static "robots.txt");
        Log.debug (fun m -> m "Serving robots.txt");
        Some (serve_robots_txt ())
      )
    else
      (
        Log.debug (fun m -> m "Did not find a static file for %S" path);
        None
      )
