open Nes
open Html
open Utils

let create status =
  Page.make'
    ~title: (lwt "Oooops!")
    ~subtitles: [
      txt (Cohttp.Code.string_of_status status);
    ]
    [
      p [
        txt "While trying to access: ";
        a ~a: [a_href @@ get_uri ()] [txt @@ Uri.pct_decode @@ Uri.to_string @@ get_uri ()]
      ];
      p [
        txt @@
          match status with
          | `Not_found ->
            "You have just hit the famous “404 Not Found” page. Congratulations! \
           Or sorry, one of the two. If you believe that there is something in \
           there indeed, and that you should see it, maybe you need to sign in? \
           Otherwise, feel free to report it to your system administrator."
          | `Forbidden ->
            "You have tried to do something that your are not permitted to do. If \
           you believe that you should be allowed to do that, maybe you need to \
           sign in? Otherwise, feel free to report it to your system \
           administrator."
          | `Internal_server_error ->
            "It's not you; it's me! Something went horribly wrong on the \
           server-side. Please report it to your system administrator."
          | _ ->
            "It's not you; it's me! You have encountered a situation that was not \
           foreseen by the developpers of Dancelor. Please report it to your \
           system administrator."
      ]
    ]
