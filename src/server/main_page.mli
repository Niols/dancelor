val serve :
  Environment.t ->
  string ->
  (string * string list) list ->
  (Environment.session_cookie_action
  * Cohttp_lwt_unix.Server.response) Lwt.t
