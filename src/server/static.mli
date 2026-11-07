val base_url : Uri.t
val file_path : string -> string

val serve :
  Environment.t ->
  string ->
  (Environment.session_cookie_action
  * Cohttp_lwt_unix.Server.response) Lwt.t option
