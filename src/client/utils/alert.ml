open Dancelor_common

type level = Info | Warning | Danger

let level_to_bootstrap_class = function
  | Info -> "alert-info"
  | Warning -> "alert-warning"
  | Danger -> "alert-danger"

let level_to_default_icon = function
  | Info -> Icon.(Alert Info)
  | Warning -> Icon.(Alert Warning)
  | Danger -> Icon.(Alert Danger)

let make ~level ?icon content =
  let open Html in
  div ~a: [a_class ["m-0"; "alert"; level_to_bootstrap_class level; "d-flex"]] [
    Icon.html ~i ~a_class ~a_title (Option.value icon ~default: (level_to_default_icon level));
    div ~a: [a_class ["ms-2"]] content;
  ];
