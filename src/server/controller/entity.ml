open Nes
open Dancelor_common

let resource_type env id =
  let actor_id = Environment.actor_id env in
  match%lwt Database.Entity.get_type ~actor_id id with
  | Some (#Resource_type.t as type_) -> lwt type_
  | _ -> Shared.reject_can_get ()

let entity_rows env ids =
  let (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids, group_ids) =
    List.fold_left
      (fun
          (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids, group_ids)
          id
        ->
        match id with
        | `Person id -> (id :: person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids, group_ids)
        | `Dance id -> (person_ids, id :: dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids, group_ids)
        | `Source id -> (person_ids, dance_ids, id :: source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids, group_ids)
        | `Tune id -> (person_ids, dance_ids, source_ids, id :: tune_ids, version_ids, set_ids, book_ids, user_ids, group_ids)
        | `Version id -> (person_ids, dance_ids, source_ids, tune_ids, id :: version_ids, set_ids, book_ids, user_ids, group_ids)
        | `Set id -> (person_ids, dance_ids, source_ids, tune_ids, version_ids, id :: set_ids, book_ids, user_ids, group_ids)
        | `Book id -> (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, id :: book_ids, user_ids, group_ids)
        | `User id -> (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, id :: user_ids, group_ids)
        | `Group id -> (person_ids, dance_ids, source_ids, tune_ids, version_ids, set_ids, book_ids, user_ids, id :: group_ids)
      )
      ([], [], [], [], [], [], [], [], [])
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
  and row_for_group = Group.get_row_for env group_ids
  in
  lwt @@
    List.filter_map
      (function
        (* resources *)
        | `Person id -> Option.map Resource_row.person @@ row_for_person id
        | `Dance id -> Option.map Resource_row.dance @@ row_for_dance id
        | `Source id -> Option.map Resource_row.source @@ row_for_source id
        | `Tune id -> Option.map Resource_row.tune @@ row_for_tune id
        | `Version id -> Option.map Resource_row.version @@ row_for_version id
        | `Set id -> Option.map Resource_row.set @@ row_for_set id
        | `Book id -> Option.map Resource_row.book @@ row_for_book id
        (* principals *)
        | `User id -> Option.map Principal_row.user @@ row_for_user id
        | `Group id -> Option.map Principal_row.group @@ row_for_group id
      )
      ids

let principal_row env (id : Principal_id.t) : Principal_row.t Lwt.t =
  let%lwt rows =
    List.map (function #Principal_row.t as r -> r | _ -> assert false)
    <$> entity_rows env [id]
  in
  match rows with
  | [] -> Shared.reject_can_get ()
  | [row] -> lwt row
  | _ -> assert false

let resource_rows env (ids : Resource_id.t list) : Resource_row.t list Lwt.t =
  List.map (function #Resource_row.t as r -> r | _ -> assert false)
  <$> entity_rows env ids

let newest_resources env limit =
  resource_rows env =<< Database.Entity.get_newest_resources ~actor_id: (Environment.actor_id env) ~limit

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
  Search_result.map (Pair.map_fst Resource_row.person) <$> Person.search' env query

let search'_dance env query =
  Search_result.map (Pair.map_fst Resource_row.dance) <$> Dance.search' env query

let search'_source env query =
  Search_result.map (Pair.map_fst Resource_row.source) <$> Source.search' env query

let search'_tune env query =
  Search_result.map (Pair.map_fst Resource_row.tune) <$> Tune.search' env query

let search'_version env query =
  Search_result.map (Pair.map_fst Resource_row.version) <$> Version.search' env query

let search'_set env query =
  Search_result.map (Pair.map_fst Resource_row.set) <$> Set.search' env query

let search'_book env query =
  Search_result.map (Pair.map_fst Resource_row.book) <$> Book.search' env query

let search'_user env query =
  Search_result.map (Pair.map_fst Principal_row.user) <$> User.search' env query

let search'_group env query =
  Search_result.map (Pair.map_fst Principal_row.group) <$> Group.search' env query

module Generic_entity_search = struct
  let person env common =
    search'_person env {common; specific = Person_query.make_specific ()}

  let dance env common =
    search'_dance env {common; specific = Dance_query.make_specific ()}

  let source env common =
    search'_source env {common; specific = Source_query.make_specific ()}

  let tune env common =
    search'_tune env {common; specific = Tune_query.make_specific ()}

  let version env common =
    search'_version env {common; specific = Version_query.make_specific ()}

  let set env common =
    search'_set env {common; specific = Set_query.make_specific ()}

  let book env common =
    search'_book env {common; specific = Book_query.make_specific ()}

  let user env common =
    search'_user env {common; specific = User_query.make_specific ()}

  let group env common =
    search'_group env {common; specific = Group_query.make_specific ()}

  let make
    ~search_functions
    ~restrict_result_type
  = fun env query ->
    let%lwt results = Lwt_list.map_p (fun search' -> search' env query) search_functions in
    let total = List.fold_left (fun total result -> total + result.Search_result.total) 0 results in
    let items =
      (* NOTE: Mind the order of [s1] and [s2]: we sort scores descending *)
      list_merge_sorted_l_on
        (fun (_, s1) (_, s2) -> Float.compare s2 s1)
        (List.map (fun result -> result.Search_result.items) results)
    in
    let items = List.map (Pair.map_fst restrict_result_type) items in
    lwt {Search_result.total; items}
end

let cache_principals : (Environment.cache_key * Principal_query.t, (Principal_row.t * float) Search_result.t Lwt.t) Cache.t =
  Cache.create ~lifetime: 60 ()

let search_principals' =
  let search_principals' =
    Generic_entity_search.make
      ~search_functions: Generic_entity_search.[user; group]
      ~restrict_result_type: (function
        | (`User _ | `Group _) as p -> p
        | _ -> assert false
      )
  in
  fun env ({common; specific}: Principal_query.t) ->
    Cache.use ~cache: cache_principals ~key: (Environment.cache_key env, {common; specific}) @@ fun () ->
    match specific with
    | None -> search_principals' env common
    | Some`User specific -> search'_user env {common; specific}
    | Some`Group specific -> search'_group env {common; specific}

let search_principals env slice query =
  let%lwt {total; items} = search_principals' env query in
  let items = List.map fst @@ Slice.list ~strict: false slice items in
  lwt {Search_result.total; items}

let cache_resources : (Environment.cache_key * Resource_query.t, (Resource_row.t * float) Search_result.t Lwt.t) Cache.t =
  Cache.create ~lifetime: 60 ()

let search_resources' =
  let search_resources' =
    Generic_entity_search.make
      ~search_functions: Generic_entity_search.[person; dance; source; tune; version; set; book]
      ~restrict_result_type: (function
        | (`Person _ | `Dance _ | `Source _ | `Tune _ | `Version _ | `Set _ | `Book _) as r -> r
        | _ -> assert false
      )
  in
  fun env ({common; specific}: Resource_query.t) ->
    Cache.use ~cache: cache_resources ~key: (Environment.cache_key env, {common; specific}) @@ fun () ->
    match specific with
    | None -> search_resources' env common
    | Some`Person specific -> search'_person env {common; specific}
    | Some`Dance specific -> search'_dance env {common; specific}
    | Some`Source specific -> search'_source env {common; specific}
    | Some`Tune specific -> search'_tune env {common; specific}
    | Some`Version specific -> search'_version env {common; specific}
    | Some`Set specific -> search'_set env {common; specific}
    | Some`Book specific -> search'_book env {common; specific}

let search_resources env slice query =
  let%lwt {total; items} = search_resources' env query in
  let items = List.map fst @@ Slice.list ~strict: false slice items in
  lwt {Search_result.total; items}

let search_resources_context_5_10 env query element =
  let%lwt results = Search_result.items <$> search_resources env Slice.everything query in
  match List.find_context ~n_prev: 5 ~n_next: 10 (Resource_id.equal element) (List.map Resource_row.to_id results) with
  | None ->
    Madge_server.shortcut_not_found "Could not find the given element in the search results."
  | Some List.{index; total; next; previous; element = _} ->
    lwt {Search_context_result.index; total; next; previous}

let assert_can_edit_permissions env db id f =
  let actor_id = Environment.actor_id env in
  match%lwt Database.Entity.get_permission db ~actor_id id with
  | None ->
    (* not even read permissions on the item *)
    Shared.reject_can_get ()
  | Some permission ->
    match Permission.share_reason permission with
    | None ->
      (* no permission to share *)
      Madge_server.shortcut_forbidden "You cannot edit permissions for this object"
    | Some _reason ->
      f ~entity_is_public: permission.entity_is_public

let get_permissions env id =
  Database.with_ @@ fun db ->
  assert_can_edit_permissions env db id @@ fun ~entity_is_public ->
  let%lwt actor_roles = Database.Entity.get_actor_roles db id in
  lwt {Permissions_form.entity_is_public; actor_roles}

let set_permissions env id {Permissions_form.entity_is_public; actor_roles} =
  Database.with_ @@ fun db ->
  assert_can_edit_permissions env db id @@ fun ~entity_is_public: entity_was_public ->
  (
    if entity_is_public <> entity_was_public then
      Database.Entity.set_is_public db id entity_is_public
    else
      lwt_unit
  );%lwt
  Database.Entity.set_actor_roles db id actor_roles

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Entity.t -> a = fun env endpoint ->
  match endpoint with
  | Principal_row -> principal_row env
  | Resource_type -> resource_type env
  | Resource_rows -> resource_rows env
  | Newest_resources -> newest_resources env
  | Search_principals -> search_principals env
  | Search_resources -> search_resources env
  | Search_resources_context_5_10 -> search_resources_context_5_10 env
  | Get_permissions -> get_permissions env
  | Set_permissions -> set_permissions env
