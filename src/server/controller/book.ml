open NesUnix
open Dancelor_common
open Model_new
open Search_new

include Shared.Make_private(struct
  type id = Book_id.t
  type row = Book_row.t
  type view = Book_view.t
  type query = Book_query.t
  include Database.Book
end)

(* Bit of a hack *)

module Warnings = struct
  (** The following functions all have the name of a warning of
      {!Book_view.warning}. They all are in charge of generating a
      list of the associated warning corresponding to the given
      book. The {!all} function then gathers all these warnings in a
      common list. *)

  let empty (book : Book_view.t) = if book.content = [] then [Book_view.Empty] else []

  let tunes_from_content (book : Book_view.t) : Tune_name.t list =
    List.concat_map
      (function
        | Book_view.Versions versions_and_params -> List.map (Tune_row.to_name % Version_row.tune % fst) versions_and_params
        | _ -> []
      )
      book.content

  let sets_from_content ~actor_id (book : Book_view.t) : Set_view.t list Lwt.t =
    let set_rows : Set_row.t list =
      List.filter_map
        (function
          | Book_view.Dance (_, Dance_set (Allowed set, _)) | Set (Allowed set, _) -> Some set
          | Part _ | Dance (_, Dance_only) | Dance (_, Dance_versions _) | Dance (_, Dance_set (Forbidden, _)) | Versions _ | Set (Forbidden, _) -> None
        )
        book.content
    in
    (* FIXME: Ugly as hell, and very inefficient, especially since
       this is only to grab the versions. SQL would do that much better. *)
    Lwt_list.filter_map_s (fun s -> Database.Set.get_view ~actor_id s.Set_row.id) set_rows

  let duplicate_set ~actor_id book =
    let%lwt sets = sets_from_content ~actor_id book in
    match List.sort (fun s1 s2 -> Entry.Id.compare' s1.Set_view.id s2.id) sets with
    | [] -> lwt_nil
    | first_set :: other_sets ->
      let (_, warnings) =
        List.fold_left
          (fun (previous_set, warnings) current_set ->
            let warnings =
              if Entry.Id.equal' current_set.Set_view.id previous_set.Set_view.id then
                  (Book_view.Duplicate_set (Set_view.to_name current_set) :: warnings)
              else
                warnings
            in
              (current_set, warnings)
          )
          (first_set, [])
          other_sets
      in
      lwt warnings

  let unique_sets_from_content ~actor_id book =
    let%lwt sets = sets_from_content ~actor_id book in
    lwt @@ List.sort_uniq (fun s1 s2 -> Entry.Id.compare' s1.Set_view.id s2.Set_view.id) sets

  let duplicate_tune ~actor_id book =
    let%lwt sets = unique_sets_from_content ~actor_id book in
    let standalone_tunes = tunes_from_content book in
    (* [tunes_to_sets] is a hashtable from tunes to sets they belong to.
       Standalone tunes are associated with None *)
    let tunes_to_sets = Hashtbl.create 8 in
    (* register standalone tunes *)
    List.iter
      (fun t ->
        Hashtbl.add tunes_to_sets t None
      )
      standalone_tunes;
    (* register tunes in sets *)
    List.iter
      (fun set ->
        List.iter
          (fun (v, _) ->
            Hashtbl.add tunes_to_sets (Tune_row.to_name v.Version_row.tune) (Some set)
          )
          set.Set_view.content
      )
      sets;
    (* crawl all registered tunes and see if they appear several times. if that is
       the case, add a warning accordingly *)
    Hashtbl.to_seq_keys tunes_to_sets
    |> List.of_seq
    |> List.fold_left
        (fun warnings tune ->
          let set_opts = List.sort_count (Option.compare (fun s1 s2 -> Entry.Id.compare' s1.Set_view.id s2.id)) (Hashtbl.find_all tunes_to_sets tune) in
          let set_opts = List.map (Pair.map_fst (Option.map Set_view.to_name)) set_opts in
          if List.length set_opts > 1 then
            Book_view.Duplicate_tune (tune, set_opts) :: warnings
          else
            warnings
        )
        []
    |> lwt

  let set_dance_kind_mismatch (book : Book_view.t) =
    List.filter_map
      (function
        | Book_view.Dance (dance, Dance_set (Allowed set, _)) ->
          if dance.kind <> set.kind then
            Some (Book_view.Set_dance_kind_mismatch (Set_row.to_name set, Dance_row.to_name dance))
          else
            None
        | _ -> None
      )
      book.content

  let all ~actor_id book =
    Lwt_list.fold_left_s
      (fun warnings new_warnings_lwt ->
        let%lwt new_warnings = new_warnings_lwt in
        lwt (warnings @ new_warnings)
      )
      []
      [
        (lwt @@ empty book);
        duplicate_set ~actor_id book;
        duplicate_tune ~actor_id book;
        (lwt @@ set_dance_kind_mismatch book);
      ]
end

let get_view env book =
  (* FIXME: hackish; should be handled directly in the DB *)
  let%lwt book = get_view env book in
  let%lwt warnings = Warnings.all ~actor_id: (Environment.actor_id env) book in
  lwt {book with warnings}

(* Legacy *)

let get env id =
  match%lwt Database.Book.get id with
  | None -> Permission.reject_can_get ()
  | Some book ->
    Permission.assert_can_get_private env book;%lwt
    lwt book

let create env book access =
  Permission.assert_can_create_private env;%lwt
  Database.Book.create book access

let update env id book access =
  Permission.assert_can_update_private env =<< get env id;%lwt
  Database.Book.update id book access

let delete env id =
  Permission.assert_can_delete_private env =<< get env id;%lwt
  Database.Book.delete id

let build_pdf env id book_params rendering_params =
  get env id >>= fun book ->
  let%lwt book = Model_to_renderer.book_to_renderer_book' book book_params in
  let book_pdf_arg = Model_to_renderer.renderer_book_to_renderer_book_pdf_arg book rendering_params in
  uncurry Job.register_job_and_file <$> Renderer.make_book_pdf book_pdf_arg

let build_zip env id book_params rendering_params =
  get env id >>= fun book ->
  let%lwt sets =
    Lwt_list.filter_map_s
      (fun page ->
        match%lwt Model_to_renderer.page_to_renderer_page page book_params with
        | (Part _, _) -> lwt_none
        | (Set set, pdf_metadata) -> lwt_some {Renderer.set; pdf_metadata}
      )
      (Model.Book.contents' book)
  in
  let sets = NEList.of_list_exn sets in
  let sets_zip_arg = Model_to_renderer.renderer_sets_to_renderer_sets_zip_arg sets rendering_params in
  uncurry Job.register_job_and_file <$> Renderer.make_sets_zip sets_zip_arg

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Book.t -> a = fun env endpoint ->
  match endpoint with
  | Get -> get env
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_rows -> get_rows env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Delete -> delete env
  | Build_pdf -> build_pdf env
  | Build_zip -> build_zip env
