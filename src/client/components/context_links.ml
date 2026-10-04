open Nes
open Dancelor_common
open Html
open Utils

module Log = (val Logs.src_log @@ Logs.Src.create "client.components.context-links": Logs.LOG)

let walk_2_forward_1_back ~forward ~back =
  let [@tail_mod_cons] rec aux = function
    | (fwd, []) -> fwd
    | ([], bck) -> bck
    | ([x], bck) -> x :: bck
    | (x :: y :: fwd, z :: bck) -> x :: y :: z :: aux (fwd, bck)
  in
  aux (forward, back)

let lwt_list_iter_n ?max_concurrency f l =
  Lwt_stream.iter_n ?max_concurrency f (Lwt_stream.of_list l)

let preload_pages_from_context ~page_descr ~versions_in_page ~previous ~next =
  (* Give the page a little bit of time to settle and load its own contents. *)
  Js_of_ocaml_lwt.Lwt_js.sleep 2.;%lwt
  Log.info (fun m -> m "Preloading versions on other pages of the context.");
  Lwt_list.iter_s
    (fun page ->
      Log.debug (fun m -> m "Preloading versions for %s" @@ page_descr page);
      (* For all the versions of the page in parallel, ask the server to
         build the snippets, then wait until the stream of statuses
         drains, which is when building succeeded or failed. *)
      lwt_list_iter_n
        ~max_concurrency: 4
        (fun (version_id, params) ->
          let response_promise =
            Api.call_exn
              (Version Build_snippets)
              version_id
              params
              Rendering_parameters.none
          in
          Lwt_stream.iter (fun _ -> ()) @@
            Job.status_stream
              (NesSlug.of_string "dummy")
              (
                Endpoints.Version.map_copyright_response
                  (Endpoints.Job.map_registration_response Endpoints.Version.Snippet_ids.svg_job_id)
                <$> response_promise
              )
        )
      =<< versions_in_page page
    )
    (
      (* NOTE: Heuristic: we don't know in which direction the user is
         going to go, so we generate the next and the previous
         page, and, after that, we bias towards the user going forward. *)
      walk_2_forward_1_back ~forward: next ~back: previous
    );%lwt
  Log.info (fun m -> m "Done preloading versions in the context.");
  lwt_unit

let no_context_links () = div []

let make_and_render_gen
    ~(parent_page : Uri.t S.t)
    ~(this_page : Uri.t option)
    ~(index_total_category_name_lwt : _ Lwt.t)
    ~(page_href : 'page -> Uri.t Lwt.t)
    ~(page_descr : 'page -> string)
    ~(versions_in_page : 'page -> (Version_id.t * Model_builder.Core.Version_parameters.t) list Lwt.t)
    ~(previous_next_lwt : ('page list * 'page list) option Lwt.t)
  =
  Lwt.async (fun () ->
    match%lwt previous_next_lwt with
    | None -> lwt_unit
    | Some (previous, next) -> preload_pages_from_context ~page_descr ~versions_in_page ~previous ~next
  );
  let overview_block =
    div ~a: [a_class ["col"; "ps-0"; "text-truncate"]] [
      with_span_placeholder
        (
          let%lwt (index, total, category, name) = index_total_category_name_lwt in
          lwt @@
            (
              txtf
                "%s of %s in %s"
                (Option.fold index ~some: (string_of_int % ((+) 1)) ~none: "??")
                (Option.fold total ~some: string_of_int ~none: "??")
                category;
            ) :: (
              match name with
              | None -> []
              | Some name -> [txtf ": "; a ~a: [R.a_href parent_page] [txt name]]
            )
        );
    ]
  in
  let back_clear_links = [
    Button.make_a
      ~classes: ["btn-secondary"]
      ~icon: (Action Back)
      ~tooltip: "Go back to the parent page, be it a search, a set, \
                   or anything else."
      ~href: parent_page
      ();
    Button.make_a
      ~classes: ["btn-warning"]
      ~icon: (Action Clear)
      ~tooltip: "Reload the current page without the context. This will get \
                   rid of this banner and of the side links."
      ~disabled: (S.const @@ Option.is_none this_page)
      ~href: (S.const @@ Option.value this_page ~default: Uri.empty)
      ();
  ]
  in
  let prev_next_links = [
    R.div ~a: [a_class ["d-inline-block"; "ms-1"]] (
      S.map
        (
          Option.value
            ~default: [
              Button.make
                ~classes: ["btn-secondary"; "placeholder"]
                ~icon: (Action Move_left)
                ~disabled: (S.const true)
                ();
              Button.make
                ~classes: ["btn-secondary"; "placeholder"]
                ~icon: (Action Move_right)
                ~disabled: (S.const true)
                ();
            ]
        ) @@
      S.from_lwt None @@
      Lwt.flip_map previous_next_lwt @@
      Option.map @@ fun (previous, next) ->
      [
        Button.make_a
          ~classes: ["btn-secondary"]
          ~icon: (Action Move_left)
          ~disabled: (S.const @@ List.is_empty previous)
          ~tooltip: "Go to the previous element in the context."
          ~href: (
            S.map (Option.value ~default: Uri.empty) @@
            S.from_lwt None @@
            match List.hd_opt previous with
            | None -> lwt_none
            | Some page -> some <$> page_href page
          )
          ();
        Button.make_a
          ~classes: ["btn-secondary"]
          ~icon: (Action Move_right)
          ~disabled: (S.const @@ List.is_empty next)
          ~tooltip: "Go to the next element in the context."
          ~href: (
            S.map (Option.value ~default: Uri.empty) @@
            S.from_lwt None @@
            match List.hd_opt next with
            | None -> lwt_none
            | Some page -> some <$> page_href page
          )
          ();
      ]
    );
  ]
  in
  div [
    (* NOTE: negative top margin must be kept in sync with header's margin *)
    div
      ~a: [a_class ["bg-secondary-subtle"; "mt-n2"; "mb-2"; "opacity-75"]]
      [
        div ~a: [a_class ["container-md"]] [
          div ~a: [a_class ["row"; "m-0"; "align-items-center"]] [
            overview_block;
            div
              ~a: [a_class ["col-auto"; "text-end"; "p-0"]]
              (back_clear_links @ prev_next_links)
          ];
        ];
      ]
  ]

let for_search query (any_id : Any_id.t) =
  Option.fold
    query
    ~none: (no_context_links ())
    ~some: (fun (query : Endpoints.Page.In_search.t) ->
      let query = Endpoints.Page.In_search.project query in
      let neighbours_lwt =
        let%olwt query = lwt @@ Result.to_option @@ Any_query.parse query in
        Result.to_option <$> Api.call (Any Search_context_5_10) query any_id
      in
      let parent_page =
        let open Endpoints.Page in
        S.bind (S.from_lwt None (Lwt.map (Option.map Search_context_result.index) neighbours_lwt)) @@ fun index ->
        let page = Option.map (fun index -> 1 + index / Search.entries_per_page) index in
        (* NOTE: sync with search.ml *)
        S.const @@ href Explore query (Option.value page ~default: 1)
      in
      let this_page = Some (Endpoints.Page.href_any_full_new any_id) in
      let index_total_category_name_lwt =
        let%lwt (index, total) =
          Lwt.map
            (function
              | None -> (None, None)
              | Some {Search_context_result.index; total; _} -> (Some index, Some total)
            )
            neighbours_lwt
        in
        let (category, name) =
          if query = "" then ("all the entries", None)
          else ("search for", Some query)
        in
        lwt (index, total, category, name)
      in
      let page_href any = lwt @@ Endpoints.Page.href_any_full_new ~in_search: (Endpoints.Page.In_search.inject query) any in
      let page_descr _any = "FIXME" in
      let versions_in_page : Any_id.t -> (Version_id.t * Model_builder.Core.Version_parameters.t) list Lwt.t = function
        (** NOTE: This is about the versions that are **visible** in the any.
            In particular, we don't return the versions in a book. *)
        | Person _ | Dance _ | Source _ | User _ | Tune _ | Book _ -> lwt_nil
        | Version version ->
          lwt [(version, Model_builder.Core.Version_parameters.none)]
        | Set set ->
          let%lwt set = Api.call_exn (Set Get_view) set in
          lwt @@ List.map (Pair.map_fst Version_row.id) set.content
      in
      let previous_next_lwt =
        Lwt.map
          (Option.map (fun {Search_context_result.previous; next; _} -> (previous, next)))
          neighbours_lwt
      in
      make_and_render_gen
        ~parent_page
        ~this_page
        ~index_total_category_name_lwt
        ~page_href
        ~page_descr
        ~versions_in_page
        ~previous_next_lwt
    )

let for_set ~this_page in_set =
  Option.fold
    in_set
    ~none: (no_context_links ())
    ~some: (fun ((id : Set_id.t), index) ->
      let set_lwt = Api.call_exn (Set Get_view) id in
      let parent_page = S.const @@ Endpoints.Page.href_set id in
      let index_total_category_name_lwt =
        let%lwt set = set_lwt in
        lwt (Some index, Some (List.length set.content), "set", Some set.name)
      in
      let previous_next_lwt =
        let%lwt set = set_lwt in
        let total = List.length set.content in
        let mk index = if index < 0 || index > total - 1 then None else Some index in
        let init_indices f = List.filter_map Fun.id (List.init 5 (fun i -> mk (f i))) in
        lwt_some (init_indices (fun i -> index - 1 - i), init_indices (fun i -> index + 1 + i))
      in
      let page_href index =
        let%lwt set = set_lwt in
        let (version, _) = List.nth set.content index in
        lwt @@ Endpoints.Page.(href @@ Version View) None (Some (set.id, index)) version.id
      in
      let page_descr i = spf "version %d" i in
      let versions_in_page index =
        let%lwt set = set_lwt in
        lwt [Pair.map_fst Version_row.id @@ List.nth set.content index]
      in
      make_and_render_gen
        ~parent_page
        ~this_page: (Some this_page)
        ~index_total_category_name_lwt
        ~page_href
        ~page_descr
        ~versions_in_page
        ~previous_next_lwt
    )

let for_book (book : Book_view.t) pageno =
  let parent_page = S.const @@ Endpoints.Page.href_book book.id in
  let this_page =
    match List.nth book.contents pageno with
    | Book_view.Part _ -> None
    | Dance (_, Dance_set _) -> None (* because it's unclear which it would lead to *)
    | Dance (dance, _) -> Some (Endpoints.Page.(href @@ Dance View) None dance.id)
    | Versions [(version, _)] -> Some (Endpoints.Page.(href @@ Version View) None None version.id)
    | Versions _ -> None
    | Set (Allowed set, _) -> Some (Endpoints.Page.(href @@ Set View) None set.id)
    | Set (Forbidden, _) -> None
  in
  let total = List.length book.contents in
  let index_total_category_name_lwt =
    lwt (Some pageno, Some total, "book", Some book.name)
  in
  let previous_next_lwt =
    let mk pageno = if pageno < 0 || pageno > total - 1 then None else Some pageno in
    let init_pagenos f = List.filter_map Fun.id (List.init 5 (fun i -> mk (f i))) in
    lwt_some (init_pagenos (fun i -> pageno - 1 - i), init_pagenos (fun i -> pageno + 1 + i))
  in
  let page_href index = lwt @@ Endpoints.Page.(href @@ Book Preview) book.id index in
  let page_descr index = spf "page %d" index in
  let versions_in_page page =
    match List.nth book.contents page with
    | Part _ | Dance (_, Dance_only) -> lwt_nil
    | Set (set, _) | Dance (_, Dance_set (set, _)) ->
      (
        match set with
        | Allowed set ->
          let%lwt set = Api.call_exn (Set Get_view) set.id in
          lwt @@ List.map (Pair.map_fst Version_row.id) set.content
        | Forbidden -> lwt_nil
      )
    | Versions versions | Dance (_, Dance_versions versions) ->
      lwt @@ List.map (Pair.map_fst Version_row.id) versions
  in
  make_and_render_gen
    ~parent_page
    ~this_page
    ~index_total_category_name_lwt
    ~page_href
    ~page_descr
    ~versions_in_page
    ~previous_next_lwt
