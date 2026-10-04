open Nes
open Dancelor_common

let get_type env id =
  let actor_id = Environment.actor_id env in
  match%lwt Database.Any.get_type ~actor_id id with
  | None -> Shared.reject_can_get ()
  | Some type_ -> lwt type_

let get_rows env ids =
  let (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids) =
    List.fold_left
      (fun
          (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids)
          id
        ->
        match id with
        | Any_id.Person id -> (id :: person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids)
        | Dance id -> (person_ids, id :: dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids)
        | Source id -> (person_ids, dance_ids, id :: source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids)
        | Tune id -> (person_ids, dance_ids, source_ids, id :: tune_ids, version_ids, set_ids, book_ids, user_ids)
        | Version id -> (person_ids, dance_ids, source_ids, tune_ids, id :: version_ids, set_ids, book_ids, user_ids)
        | Set id -> (person_ids, dance_ids, source_ids, tune_ids, version_ids, id :: set_ids, book_ids, user_ids)
        | Book id -> (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, id :: book_ids, user_ids)
        | User id -> (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, id :: user_ids)
      )
      ([], [], [], [], [], [], [], [])
      ids
  in
  let%lwt row_for_person = Person.get_row_for env person_ids
  and row_for_dance = Dance.get_row_for env dance_ids
  and row_for_source = Source.get_row_for env source_ids
  and row_for_tune = Tune.get_row_for env tune_ids
  and row_for_version = Version.get_row_for env version_ids
  and row_for_set = Set.get_row_for env set_ids
  and row_for_book = Book.get_row_for env book_ids
  and row_for_user = User.get_row_for env user_ids
  in
  lwt @@
    List.filter_map
      (function
        | Any_id.Person id -> Option.map Any_row.person @@ row_for_person id
        | Dance id -> Option.map Any_row.dance @@ row_for_dance id
        | Source id -> Option.map Any_row.source @@ row_for_source id
        | Tune id -> Option.map Any_row.tune @@ row_for_tune id
        | Version id -> Option.map Any_row.version @@ row_for_version id
        | Set id -> Option.map Any_row.set @@ row_for_set id
        | Book id -> Option.map Any_row.book @@ row_for_book id
        | User id -> Option.map Any_row.user @@ row_for_user id
      )
      ids

let newest env limit =
  get_rows env =<< Database.Any.get_newest ~actor_id: (Environment.actor_id env) ~limit

(** Given two streams sorted according to the comparison function, produce one
    sorted stream of all the values. In case of equality, the left stream wins. *)
let lwt_stream_merge_sorted cmp xs ys =
  Lwt_stream.from @@ fun () ->
  let%lwt x = Lwt_stream.peek xs in
  let%lwt y = Lwt_stream.peek ys in
  match x, y with
  | Some x, Some y when cmp x y <= 0 -> Lwt_stream.junk xs;%lwt lwt_some x
  | Some _, Some y -> Lwt_stream.junk ys;%lwt lwt_some y
  | Some x, None -> Lwt_stream.junk xs;%lwt lwt_some x
  | None, Some y -> Lwt_stream.junk ys;%lwt lwt_some y
  | None, None -> lwt_none

(** Given a list of streams sorted according to the comparison function, produce
    one sorted stream of all the values. In case of equality, a stream appearing
    earlier in the list wins. *)
let lwt_stream_merge_sorted_l cmp = function
  | [] -> Lwt_stream.of_list []
  | s :: ss -> List.fold_left (lwt_stream_merge_sorted cmp) s ss

(** Given two lists sorted according to the comparison function,
    produce one sorted list of all the values. In case of equality,
    the left list wins. *)
let list_merge_sorted_on cmp xs ys =
  let rec aux = function
    | [], [] -> []
    | xs, [] -> xs
    | [], ys -> ys
    | x :: xs, ((y :: _) as ys) when cmp x y <= 0 -> x :: aux (xs, ys)
    | xs, y :: ys -> y :: aux (xs, ys)
  in
  aux (xs, ys)

(** Given a list of lists sorted according to the comparison function,
    produce one sorted list of all the values. In case of equality, a
    list appearing earlier wins. *)
let list_merge_sorted_l_on cmp = function
  | [] -> []
  | l :: ls -> List.fold_left (list_merge_sorted_on cmp) l ls

(** Slice a stream. Raises {!Invalid_argument} if [start] is strictly bigger
    than the length of the stream. If [strict] is set (the default), also raises
    {!Invalid_argument} if [end_excl] is strictly bigger than the length of the
    stream; otherwise, silently include everything until the end of the
    stream. *)
let slice_lwt_stream = fun ?(strict = true) slice xs ->
  let i = ref 0 in
  let rec next () =
    match%lwt Lwt_stream.get xs with
    | None when strict && Slice.end_incl slice <> !i - 1 -> invalid_arg "Slice.stream"
    | Some _ when Slice.start slice > !i -> incr i; next ()
    | Some x when Slice.end_incl slice >= !i -> incr i; Lwt.return_some x
    | _ -> Lwt.return_none
  in
  Lwt_stream.from next

let search'_person env query =
  Search_result.map (Pair.map_fst Any_row.person) <$> Person.search' env query

let search'_user env query =
  Search_result.map (Pair.map_fst Any_row.user) <$> User.search' env query

let search'_dance env query =
  Search_result.map (Pair.map_fst Any_row.dance) <$> Dance.search' env query

let search'_source env query =
  Search_result.map (Pair.map_fst Any_row.source) <$> Source.search' env query

let search'_tune env query =
  Search_result.map (Pair.map_fst Any_row.tune) <$> Tune.search' env query

let search'_version env query =
  Search_result.map (Pair.map_fst Any_row.version) <$> Version.search' env query

let search'_set env query =
  Search_result.map (Pair.map_fst Any_row.set) <$> Set.search' env query

let search'_book env query =
  Search_result.map (Pair.map_fst Any_row.book) <$> Book.search' env query

let search'_any env query =
  let%lwt persons_result = search'_person env {common = query; specific = Person_query.make_specific ()}
  and dances_result = search'_dance env {common = query; specific = Dance_query.make_specific ()}
  and sources_result = search'_source env {common = query; specific = Source_query.make_specific ()}
  and tunes_result = search'_tune env {common = query; specific = Tune_query.make_specific ()}
  and versions_result = search'_version env {common = query; specific = Version_query.make_specific ()}
  and sets_result = search'_set env {common = query; specific = Set_query.make_specific ()}
  and books_result = search'_book env {common = query; specific = Book_query.make_specific ()}
  and users_result = search'_user env {common = query; specific = User_query.make_specific ()}
  in
  let total =
    persons_result.total +
      dances_result.total +
      sources_result.total +
      tunes_result.total +
      versions_result.total +
      sets_result.total +
      books_result.total +
      users_result.total
  in
  let items =
    (* NOTE: Mind the order of [s1] and [s2]: we sort scores descending *)
    list_merge_sorted_l_on (fun (_, s1) (_, s2) -> Float.compare s2 s1) [
      persons_result.items;
      dances_result.items;
      sources_result.items;
      tunes_result.items;
      versions_result.items;
      sets_result.items;
      books_result.items;
      users_result.items;
    ]
  in
  lwt {Search_result.total; items}

let cache : (Environment.cache_key * Any_query.t, (Any_row.t * float) Search_result.t Lwt.t) Cache.t =
  Cache.create ~lifetime: 60 ()

let search' env ({common; specific}: Any_query.t) =
  Cache.use ~cache ~key: (Environment.cache_key env, {common; specific}) @@ fun () ->
  match specific with
  | None -> search'_any env common
  | Some Person specific -> search'_person env {common; specific}
  | Some User specific -> search'_user env {common; specific}
  | Some Dance specific -> search'_dance env {common; specific}
  | Some Source specific -> search'_source env {common; specific}
  | Some Tune specific -> search'_tune env {common; specific}
  | Some Version specific -> search'_version env {common; specific}
  | Some Set specific -> search'_set env {common; specific}
  | Some Book specific -> search'_book env {common; specific}

let search env slice query =
  let%lwt {total; items} = search' env query in
  let items = List.map fst @@ Slice.list ~strict: false slice items in
  lwt {Search_result.total; items}

let search_context_5_10 env query element =
  let%lwt results = Search_result.items <$> search env Slice.everything query in
  match List.find_context ~n_prev: 5 ~n_next: 10 (Any_id.equal element) (List.map Any_row.to_id results) with
  | None ->
    Madge_server.shortcut_not_found "Could not find the given element in the search results."
  | Some List.{index; total; next; previous; element = _} ->
    lwt {Search_context_result.index; total; next; previous}

let assert_can_edit_permissions env db id f =
  let actor_id = Environment.actor_id env in
  match%lwt Database.Entry.get_permission db ~actor_id id with
  | None ->
    (* not even read permissions on the item *)
    Shared.reject_can_get ()
  | Some permission ->
    match Permission.share_reason permission with
    | None ->
      (* no permission to share *)
      Madge_server.shortcut_forbidden "You cannot edit permissions for this object"
    | Some _reason ->
      f ~entry_is_public: permission.entry_is_public

let get_permissions env id =
  Database.with_ @@ fun db ->
  assert_can_edit_permissions env db id @@ fun ~entry_is_public ->
  let%lwt actor_roles = Database.Entry.get_actor_roles db id in
  lwt {Permissions_form.entry_is_public; actor_roles}

let set_permissions env id {Permissions_form.entry_is_public; actor_roles} =
  Database.with_ @@ fun db ->
  assert_can_edit_permissions env db id @@ fun ~entry_is_public: entry_was_public ->
  (
    if entry_is_public <> entry_was_public then
      Database.Entry.set_is_public db id entry_is_public
    else
      lwt_unit
  );%lwt
  Database.Entry.set_actor_roles db id actor_roles

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Any.t -> a = fun env endpoint ->
  match endpoint with
  | Get_type -> get_type env
  | Get_rows -> get_rows env
  | Newest -> newest env
  | Search -> search env
  | Search_context_5_10 -> search_context_5_10 env
  | Get_permissions -> get_permissions env
  | Set_permissions -> set_permissions env
