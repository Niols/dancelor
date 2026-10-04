open NesUnix
open Dancelor_common

include Shared.Make_private_full(struct
  type tag = Book_tag.t
  type id = Book_id.t
  type row = Book_row.t
  type view = Book_view.t
  type form = Book_form.t
  type query = Book_query.t
  include Database.Book
end)

let add_version_to_contents env id version_id =
  (* FIXME: make all the database endpoints take the database such that
     endpoints like this one can share a transaction *)
  (* A bit stupid to have to get a whole version row to put back into the form
     when updating the database doesn't need the row at all. On the other hand,
     updating the database doesn't happen this often. *)
  let%lwt form = get_form env id in
  let%lwt version_row = Version.get_row env version_id in
  update env id {form with contents = form.contents @ [Versions (NEList.singleton (version_row, Model_builder.Core.Version_parameters.none))]}

let add_set_to_contents env id set_id =
  (* FIXME: make all the database endpoints take the database such that
     endpoints like this one can share a transaction *)
  (* A bit stupid to have to get a whole set row to put back into the form
     when updating the database doesn't need the row at all. On the other hand,
     updating the database doesn't happen this often. *)
  let%lwt form = get_form env id in
  let%lwt set_row = Set.get_row env set_id in
  update env id {form with contents = form.contents @ [Set (set_row, Model_builder.Core.Set_parameters.none)]}

let add_dance_to_contents env id dance_id =
  (* FIXME: make all the database endpoints take the database such that
     endpoints like this one can share a transaction *)
  (* A bit stupid to have to get a whole dance row to put back into the form
     when updating the database doesn't need the row at all. On the other hand,
     updating the database doesn't happen this often. *)
  let%lwt form = get_form env id in
  let%lwt dance_row = Dance.get_row env dance_id in
  update env id {form with contents = form.contents @ [Dance (dance_row, Dance_only)]}

(* Bit of a hack *)

module Warnings = struct
  (** The following functions all have the name of a warning of
      {!Book_view.warning}. They all are in charge of generating a
      list of the associated warning corresponding to the given
      book. The {!all} function then gathers all these warnings in a
      common list. *)

  let empty (book : Book_view.t) = if book.contents = [] then [Book_view.Empty] else []

  let tunes_from_content (book : Book_view.t) : Tune_name.t list =
    List.concat_map
      (function
        | Book_view.Versions versions_and_params -> List.map (Tune_row.to_name % Version_row.tune % fst) versions_and_params
        | _ -> []
      )
      book.contents

  let sets_from_content ~actor_id (book : Book_view.t) : Set_view.t list Lwt.t =
    let set_rows : Set_row.t list =
      List.filter_map
        (function
          | Book_view.Dance (_, Dance_set (Allowed set, _)) | Set (Allowed set, _) -> Some set
          | Part _ | Dance (_, Dance_only) | Dance (_, Dance_versions _) | Dance (_, Dance_set (Forbidden, _)) | Versions _ | Set (Forbidden, _) -> None
        )
        book.contents
    in
    (* FIXME: Ugly as hell, and very inefficient, especially since
       this is only to grab the versions. SQL would do that much better. *)
    Lwt_list.filter_map_s (fun s -> Database.Set.get_view ~actor_id s.Set_row.id) set_rows

  let duplicate_set ~actor_id book =
    let%lwt sets = sets_from_content ~actor_id book in
    match List.sort (fun s1 s2 -> Id.compare' s1.Set_view.id s2.id) sets with
    | [] -> lwt_nil
    | first_set :: other_sets ->
      let (_, warnings) =
        List.fold_left
          (fun (previous_set, warnings) current_set ->
            let warnings =
              if Id.equal' current_set.Set_view.id previous_set.Set_view.id then
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
    lwt @@ List.sort_uniq (fun s1 s2 -> Id.compare' s1.Set_view.id s2.Set_view.id) sets

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
          let set_opts = List.sort_count (Option.compare (fun s1 s2 -> Id.compare' s1.Set_view.id s2.id)) (Hashtbl.find_all tunes_to_sets tune) in
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
      book.contents

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

let build_pdf env id book_params rendering_params =
  get_form env id >>= fun book ->
  let actor_id = Environment.actor_id env in
  let%lwt book = Model_to_renderer.book_to_renderer_book ~actor_id book book_params in
  let book_pdf_arg = Model_to_renderer.renderer_book_to_renderer_book_pdf_arg book rendering_params in
  uncurry Job.register_job_and_file <$> Renderer.make_book_pdf book_pdf_arg

let build_zip env id book_params rendering_params =
  get_form env id >>= fun book ->
  let actor_id = Environment.actor_id env in
  let%lwt sets =
    Lwt_list.filter_map_s
      (fun page ->
        match%lwt Model_to_renderer.page_to_renderer_page ~actor_id page book_params with
        | (Part _, _) -> lwt_none
        | (Set set, pdf_metadata) -> lwt_some {Renderer.set; pdf_metadata}
      )
      book.contents
  in
  let sets = NEList.of_list_exn sets in
  let sets_zip_arg = Model_to_renderer.renderer_sets_to_renderer_sets_zip_arg sets rendering_params in
  uncurry Job.register_job_and_file <$> Renderer.make_sets_zip sets_zip_arg

(* Dispatch *)

let dispatch : type a r. Environment.t -> (a, r Lwt.t, r) Endpoints.Book.t -> a = fun env endpoint ->
  match endpoint with
  | Get_row -> get_row env
  | Get_view -> get_view env
  | Get_form -> get_form env
  | Get_rows -> get_rows env
  | Search -> search env
  | Create -> create env
  | Update -> update env
  | Add_version_to_contents -> add_version_to_contents env
  | Add_set_to_contents -> add_set_to_contents env
  | Add_dance_to_contents -> add_dance_to_contents env
  | Delete -> delete env
  | Build_pdf -> build_pdf env
  | Build_zip -> build_zip env
