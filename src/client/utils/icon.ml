(** Type for access-specific icons. *)
type access =
  | Everyone
  | Viewer
  | Owner
  | Omniscient_administrator
  | Non_omniscient_administrator

let access_to_string = function
  | Everyone -> "globe"
  | Viewer -> "eye"
  | Owner -> "unlock-fill" (* FIXME: unlock2-fill would be better but requires Bootstrap icons 1.13.1 *)
  | Omniscient_administrator -> "shield-lock-fill"
  | Non_omniscient_administrator -> "shield-lock"

(** Type for action-specific icons. *)
type action =
  | Add
  | Apply
  | Back
  | Clear
  | Close_or_cancel
  | Deduplicate
  | Delete
  | Download
  | Edit
  | Magic
  | Move_down
  | Move_left
  | Move_right
  | Move_up
  | No_preview
  | Parameterise
  | Preview
  | Save
  | See_outside (** eg. go to SCDDB *)
  | Share
  | Search
  | Search_more
  | Stop

let action_to_string = function
  | Add -> "plus-circle"
  | Apply -> "check-circle"
  | Back -> "arrow-90deg-up"
  | Clear -> "eraser"
  | Close_or_cancel -> "x-lg"
  | Deduplicate -> "node-minus"
  | Delete -> "trash"
  | Download -> "download"
  | Edit -> "pencil-square"
  | Magic -> "magic"
  | Move_down -> "arrow-down"
  | Move_left -> "arrow-left"
  | Move_right -> "arrow-right"
  | Move_up -> "arrow-up"
  | No_preview -> "eye-slash"
  | Parameterise -> "toggles"
  | Preview -> "eye"
  | Save -> "save"
  | See_outside -> "box-arrow-up-right"
  | Share -> "share"
  | Search -> "search"
  | Search_more -> "zoom-in"
  | Stop -> "stop-circle"

(** Type for alert-specific icons. *)
type alert =
  | Info
  | Warning
  | Danger

let alert_to_string = function
  | Info -> "info-circle"
  | Warning -> "exclamation-triangle"
  | Danger -> "exclamation-diamond"

(** Type for job-specific icons. *)
type job =
  | Registering (** aka uploading *)
  | Pending
  | Running

let job_to_string = function
  | Registering -> "cloud-upload"
  | Pending -> "hourglass-bottom"
  | Running -> "cpu"

(** Type for model-specific icons. *)
type model =
  | Source
  | Person
  | Dance
  | Tune
  | Version
  | Set
  | Book
  | User
  | Group

let model_to_string = function
  | Source -> "archive"
  | Person -> "person"
  | Dance -> "person-arms-up"
  | Tune -> "music-note-list"
  | Version -> "music-note-beamed"
  | Set -> "list-stars"
  | Book -> "book"
  | User -> "person-circle"
  | Group -> "people"

(** Type for other icons. *)
type other =
  | Actions
  | Bug
  | Clipboard
  | Dancelor_home
  | Filter
  | GitHub
  | Help
  | Sign_in
  | Sign_out
  | Reload
  | File_lilypond
  | File_pdf
  | Forbidden

let other_to_string = function
  | Actions -> "three-dots-vertical"
  | Bug -> "bug"
  | Clipboard -> "clipboard"
  | Dancelor_home -> "house" (* FIXME: a custom-made Dancelor logo *)
  | Filter -> "filter"
  | GitHub -> "github"
  | File_lilypond -> "file-music"
  | File_pdf -> "file-pdf"
  | Help -> "question-circle"
  | Sign_in -> "box-arrow-in-right"
  | Sign_out -> "box-arrow-right"
  | Reload -> "arrow-clockwise"
  | Forbidden -> "lock"

type t =
  | Access of access
  | Action of action
  | Alert of alert
  | Job of job
  | Model of model
  | Other of other

let to_string = function
  | Access icon -> access_to_string icon
  | Action icon -> action_to_string icon
  | Alert icon -> alert_to_string icon
  | Job icon -> job_to_string icon
  | Model icon -> model_to_string icon
  | Other icon -> other_to_string icon

(** Generate HTML for the given icon. One can optionally pass extra HTML
    [?classes] or a [?tooltip] that is shown when hovering on the icon. *)
let html ?(classes = []) ?tooltip icon =
  let open Html in
  let a =
    List.concat [
      [a_class (["bi"; ("bi-" ^ to_string icon)] @ classes)];
      (Option.fold ~none: [] ~some: (fun t -> [a_title t]) tooltip);
    ]
  in
  i ~a []
