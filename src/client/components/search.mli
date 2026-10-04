open Nes
open Dancelor_common
open Html

val entries_per_page : int

type 'p pagination_mode =
  | Pagination of 'p
  | Fixed_slice of Slice.t

type 'result t

val search_bar : 'result t -> 'result Search_bar.t

val make :
  ?initial_input: string ->
  ?initial_page: int ->
  search: (Slice.t -> string -> ('result Search_result.t, string) result Lwt.t) ->
  pagination_mode: unit pagination_mode ->
  ?min_characters: int ->
  ?on_input: (string -> unit) ->
  ?on_enter: (string -> unit) ->
  ?on_page_change: (int -> unit) ->
  ?page_url: (int -> Uri.t S.t) ->
  unit ->
  'result t

val render :
  make_result: (?in_search: Endpoints.Page.In_search.t S.t -> 'result -> Html_types.tr Html.elt) ->
  ?results_when_no_search: 'result list ->
  ?attached_buttons: [< Html_types.div_content_fun >`I `Input] elt list ->
  ?show_table_headers: bool ->
  'result t ->
  [> Html_types.div] elt

module Quick : sig
  type 'result t

  val text : 'result t -> string S.t

  val search_bar : 'result t -> 'result Search_bar.t

  val make :
    search: (Slice.t -> string -> ('result Search_result.t, string) result Lwt.t) ->
    ?on_enter: (string -> unit) ->
    unit ->
    'result t

  val render :
    return: ('dialog_result option -> unit) ->
    dialog_title: string Lwt.t ->
    ?dialog_buttons: Html_types.div_content_fun elt list ->
    make_result: (?in_search: Endpoints.Page.In_search.t S.t -> 'result -> Html_types.tr Html.elt) ->
    ?results_when_no_search: 'result list ->
    'result t ->
    Page.t Lwt.t
end
