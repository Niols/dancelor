open Dancelor_common

val for_search : Endpoints.Page.In_search.t option -> Resource_id.t -> [> Html_types.div] Html.elt

val for_set : this_page: Uri.t -> (Set_id.t * int) option -> [> Html_types.div] Html.elt

val for_book : Book_view.t -> int -> [> Html_types.div] Html.elt
