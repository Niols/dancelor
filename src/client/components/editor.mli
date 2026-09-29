(** {1 A fully featured editor}*)

open Html
open Utils

(** {2 High-level interface} *)

type ('result, 'state) mode =
  | Create of 'state
  (** Create a model; gets a full state for initialisation. *)
  | Create_with_local_storage
  (** Create a model; gets initialised from local storage and writes to local
      storage as well. *)
  | Quick_create of string * ('result -> unit Lwt.t)
  (** Create a model; gets a string for initialisation and a callback to call
      when “save” is clicked; meant to be called from a dialog. *)
  | Edit of 'result
  | Quick_edit of 'state
[@@deriving variants]

val make_page :
  key: string ->
  icon: Icon.t ->
  submit: (('result, 'state) mode -> 'value -> 'result Lwt.t) ->
  unsubmit: ('result -> 'value Lwt.t) ->
  ?preview: ('value -> bool Lwt.t) ->
  format: ('result -> Html_types.div_content_fun Html.elt) ->
  href: ('result -> Uri.t) ->
  mode: ('result, 'state) mode ->
  ?after_save: (unit -> unit Lwt.t) ->
  ?title_suffix: string ->
  ?pre_body: Html_types.div_content_fun elt list ->
  ?post_body: Html_types.div_content_fun elt list ->
  ('value, 'state) Component.s ->
  Page.t Lwt.t
(** Make a fully-featured editor that takes a whole page.

    [mode] is an argument that decribes what kind of editor we want: is it the
    regular creation editor, connected to local storage, or is it a quick
    creation (eg. called by another editor), in which case it can carry a
    string. It is also passed to the [submit] function.

    Note the different “levels” of values. ['state] and ['value] are tied by the
    underlying component. ['value] is typically of the form [(type, (type,
    (type, ())))]. ['result] is whatever the API call returns. Note the function
    allowing to go from low to high: [~submit] allows to go from ['value] to
    ['result]. Its counterpart also exist: [~unsubmit]. *)

(** {2 Advanced use} *)

(** {2 Low-level interface}

    This interface is similar to that of components, in the sense that there are
    un-initialised and initialised variants of editors and that one can
    manipulate them. {!make_page} above is the combination of {!prepare},
    {!initialise} and {!page} below *)

type ('result, 'value, 'state) s
(** An un-initialised editor. *)

val prepare :
  key: string ->
  icon: Icon.t ->
  submit: (('result, 'state) mode -> 'value -> 'result Lwt.t) ->
  unsubmit: ('result -> 'value Lwt.t) ->
  ?preview: ('value -> bool Lwt.t) ->
  format: ('result -> Html_types.div_content_fun Html.elt) ->
  href: ('result -> Uri.t) ->
  ('value, 'state) Component.s ->
  ('result, 'value, 'state) s

val prepare_nosubmit :
  key: string ->
  icon: Icon.t ->
  ?preview: ('value -> bool Lwt.t) ->
  format: ('value -> Html_types.div_content_fun Html.elt) ->
  href: ('value -> Uri.t) ->
  ('value, 'state) Component.s ->
  ('value, 'value, 'state) s
(** Variant of {!prepare} for an editor that does not include submission, thus
    conflating ['value] and ['result]. *)

type ('result, 'value, 'state) t
(** An initialised editor. *)

val initialise :
  ('result, 'value, 'state) s ->
  ('result, 'state) mode ->
  ('result, 'value, 'state) t Lwt.t

val page :
  ?after_save: (unit -> unit Lwt.t) ->
  ?title_suffix: string ->
  ?pre_body: Html_types.div_content_fun elt list ->
  ?post_body: Html_types.div_content_fun elt list ->
  ('result, 'value, 'state) t ->
  Page.t Lwt.t
(** Render an initialised editor as a full page, ready for use. The additional
    [?after_save] argument can be used to trigger an action from the outside,
    such as closing the dialog. By default, it clears the editor. If overridden,
    one might want to do that manually. *)

(** {3 Editor manipulation} *)

val empty :
  ('result, 'value, 'state) s ->
  'state

val state_of_yojson :
  ('result, 'value, 'state) s ->
  Yojson.Safe.t ->
  ('state, string) result

val state_to_yojson :
  ('result, 'value, 'state) s ->
  'state ->
  Yojson.Safe.t

val result_to_state :
  ('result, 'value, 'state) s ->
  'result ->
  'state Lwt.t

val key :
  ('result, 'value, 'state) s ->
  string

val s :
  ('result, 'value, 'state) t ->
  ('result, 'value, 'state) s

val state :
  ('result, 'value, 'state) t ->
  'state S.t

val signal :
  ('result, 'value, 'state) t ->
  ('value, string) result S.t

val set :
  ('result, 'value, 'state) t ->
  'result ->
  unit Lwt.t

val clear :
  ('result, 'value, 'state) t ->
  unit Lwt.t
