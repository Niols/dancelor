open Nes
open Dancelor_common
open Sql_to_name
open Sql_to_row
open Sql_to_view
open Sql_to_form
open Form_to_sql

module Book_sql = Book_sql.Sqlgg(Sqlgg_postgresql)

let get_version_sources_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_version_sources_for db ~book_ids) (fun k ~version_id -> source_sql_to_short_name ~k: (k version_id))

let get_version_arrangers_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_version_arrangers_for db ~book_ids) (fun k ~version_id -> person_sql_to_name ~k: (k version_id))

let get_tune_composers_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_tune_composers_for db ~book_ids) (fun k ~tune_id -> person_sql_to_name ~k: (k tune_id))

let get_authors_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_authors_for db ~book_ids) (fun k ~book_id -> person_sql_to_name ~k: (k book_id))

let get_sources_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_sources_for db ~book_ids) (fun k ~book_id -> source_sql_to_name ~k: (k book_id))

let get_source_rows_for db book_ids =
  let%lwt editors_for =
    Utils.fold_to_get_list
      (Book_sql.Fold.get_editors_for_sources_of db ~book_ids)
      (fun k ~source_id -> person_sql_to_name ~k: (k source_id))
  in
  Utils.fold_to_get_list (Book_sql.Fold.get_source_rows_for db ~book_ids) (fun k ~book_id ~id ->
    source_sql_to_row
      ~id
      ~editors: (editors_for id)
      ~k: (k book_id)
  )

let get_dance_devisers_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_dance_devisers_for db ~book_ids) (fun k ~dance_id -> person_sql_to_name ~k: (k dance_id))

let get_set_tunes_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_set_tunes_for db ~book_ids) (fun k ~set_id -> version_sql_to_name ~k: (k set_id))

let get_set_conceptors_for db book_ids =
  Utils.fold_to_get_list (Book_sql.Fold.get_set_conceptors_for db ~book_ids) (fun k ~set_id -> person_sql_to_name ~k: (k set_id))

let get_content_versions_for db book_ids =
  let%lwt version_sources_for = get_version_sources_for db book_ids in
  let%lwt version_arrangers_for = get_version_arrangers_for db book_ids in
  let%lwt tune_composers_for = get_tune_composers_for db book_ids in
  Utils.fold_to_get_list
    (Book_sql.Fold.get_content_versions_for db ~book_ids)
    (fun
        k
        ~book_id
        ~content_index
        ~version_id
        ~tune_id
        ~version_disambiguation
        ~version_monolithic_bars
        ~version_monolithic_or_default_structure
        ~tune_name
        ~tune_kind
        ~version_parameter_transposition_semitones
        ~version_parameter_first_bar
        ~version_parameter_clef
        ~version_parameter_structure
        ~version_parameter_trivia
        ~version_parameter_display_name
        ~version_parameter_display_composer
      ->
      let version =
        version_sql_to_row
          ~id: version_id
          ~disambiguation: version_disambiguation
          ~monolithic_bars: version_monolithic_bars
          ~monolithic_or_default_structure: version_monolithic_or_default_structure
          ~tune_id
          ~tune_name
          ~tune_kind
          ~sources: (version_sources_for version_id)
          ~arrangers: (version_arrangers_for version_id)
          ~tune_composers: (tune_composers_for tune_id)
          ~k: Fun.id
      in
      let version_params =
        Version_parameters.make
          ?transposition: (Option.map (Music.Transposition.from_semitones % Int64.to_int) version_parameter_transposition_semitones)
          ?first_bar: (Option.map Int64.to_int version_parameter_first_bar)
          ?clef: (Option.map Music.Clef.of_string version_parameter_clef)
          ?structure: (Option.map (Option.get % Version_parameters.maybe_structure_of_string % NEString.of_string_exn) version_parameter_structure)
          ?trivia: version_parameter_trivia
          ?display_name: (Option.map NEString.of_string_exn version_parameter_display_name)
          ?display_composer: (Option.map NEString.of_string_exn version_parameter_display_composer)
          ()
      in
      k (book_id, content_index) (version, version_params)
    )

let get_contents_for ~actor_id db book_ids =
  let%lwt dance_devisers_for = get_dance_devisers_for db book_ids in
  let%lwt tunes_for = get_set_tunes_for db book_ids in
  let%lwt set_conceptors_for = get_set_conceptors_for db book_ids in
  let%lwt content_versions_for = get_content_versions_for db book_ids in
  Utils.fold_to_get_list
    (Book_sql.Fold.get_content_for db ~actor_id ~book_ids)
    (fun
        k
        ~book_id
        ~page_type
        ~index
        ~part_title
        ~dance_id
        ~dance_name
        ~dance_kind
        ~dance_disambiguation
        ~set_id
        ~set_name
        ~set_kind
        ~set_entity_is_public
        ~set_actor_role
        ~set_actor_group_id
        ~set_actor_group_name
        ~set_actor_is_omniscient_administrator
        ~set_parameter_display_name
        ~set_parameter_display_conceptor
        ~set_parameter_display_kind
        ~set_parameter_version_parameter_transposition_semitones
        ~set_parameter_version_parameter_first_bar
        ~set_parameter_version_parameter_clef
        ~set_parameter_version_parameter_structure
        ~set_parameter_version_parameter_trivia
        ~set_parameter_version_parameter_display_name
        ~set_parameter_version_parameter_display_composer
      ->
      let set_params =
        Set_parameters.make
          ?display_name: (Option.map NEString.of_string_exn set_parameter_display_name)
          ?display_conceptor: (Option.map NEString.of_string_exn set_parameter_display_conceptor)
          ?display_kind: (Option.map NEString.of_string_exn set_parameter_display_kind)
          ~every_version: (
            Version_parameters.make
              ?transposition: (Option.map (Music.Transposition.from_semitones % Int64.to_int) set_parameter_version_parameter_transposition_semitones)
              ?first_bar: (Option.map Int64.to_int set_parameter_version_parameter_first_bar)
              ?clef: (Option.map Music.Clef.of_string set_parameter_version_parameter_clef)
              ?structure: (Option.map (Option.get % Version_parameters.maybe_structure_of_string % NEString.of_string_exn) set_parameter_version_parameter_structure)
              ?trivia: set_parameter_version_parameter_trivia
              ?display_name: (Option.map NEString.of_string_exn set_parameter_version_parameter_display_name)
              ?display_composer: (Option.map NEString.of_string_exn set_parameter_version_parameter_display_composer)
              ()
          )
          ()
      in
      let dance =
        Option.map
          (fun dance_id ->
            dance_sql_to_row
              ~id: dance_id
              ~name: (Option.get dance_name)
              ~kind: (Option.get dance_kind)
              ~disambiguation: dance_disambiguation
              ~devisers: (dance_devisers_for dance_id)
              ~k: Fun.id
          )
          dance_id
      in
      let set =
        Option.map
          (fun set_id ->
            match set_entity_is_public, (* set_actor_role, *) set_actor_is_omniscient_administrator with
            | None, (* None, *) None -> Forbidden
            | Some set_entity_is_public, (* Some set_actor_role, *) Some set_actor_is_omniscient_administrator ->
              Allowed (
                set_sql_to_row
                  ~id: set_id
                  ~entity_is_public: set_entity_is_public
                  ~actor_role: set_actor_role
                  ~actor_group_id: set_actor_group_id
                  ~actor_group_name: set_actor_group_name
                  ~actor_is_omniscient_administrator: set_actor_is_omniscient_administrator
                  ~name: (Option.get set_name)
                  ~kind: (Option.get set_kind)
                  ~conceptors: (set_conceptors_for set_id)
                  ~tunes: (tunes_for set_id)
                  ~k: Fun.id
              )
            | _ -> assert false
          )
          set_id
      in
      let page =
        match page_type with
        | `Part -> Book_view.Part (Option.get part_title)
        | `Dance_only -> Dance (Option.get dance, Dance_only)
        | `Dance_versions -> Dance (Option.get dance, Dance_versions (content_versions_for (book_id, index)))
        | `Dance_set -> Dance (Option.get dance, Dance_set (Option.get set, set_params))
        | `Versions -> Versions (content_versions_for (book_id, index))
        | `Set -> Set (Option.get set, set_params)
      in
      k book_id page
    )

let get_form_contents_for ~actor_id db book_ids =
  let%lwt dance_devisers_for = get_dance_devisers_for db book_ids in
  let%lwt tunes_for = get_set_tunes_for db book_ids in
  let%lwt set_conceptors_for = get_set_conceptors_for db book_ids in
  let%lwt content_versions_for = get_content_versions_for db book_ids in
  Utils.fold_to_get_list
    (Book_sql.Fold.get_content_for db ~actor_id ~book_ids)
    (fun
        k
        ~book_id
        ~page_type
        ~index
        ~part_title
        ~dance_id
        ~dance_name
        ~dance_kind
        ~dance_disambiguation
        ~set_id
        ~set_name
        ~set_kind
        ~set_entity_is_public
        ~set_actor_role
        ~set_actor_group_id
        ~set_actor_group_name
        ~set_actor_is_omniscient_administrator
        ~set_parameter_display_name
        ~set_parameter_display_conceptor
        ~set_parameter_display_kind
        ~set_parameter_version_parameter_transposition_semitones
        ~set_parameter_version_parameter_first_bar
        ~set_parameter_version_parameter_clef
        ~set_parameter_version_parameter_structure
        ~set_parameter_version_parameter_trivia
        ~set_parameter_version_parameter_display_name
        ~set_parameter_version_parameter_display_composer
      ->
      let set_params =
        Set_parameters.make
          ?display_name: (Option.map NEString.of_string_exn set_parameter_display_name)
          ?display_conceptor: (Option.map NEString.of_string_exn set_parameter_display_conceptor)
          ?display_kind: (Option.map NEString.of_string_exn set_parameter_display_kind)
          ~every_version: (
            Version_parameters.make
              ?transposition: (Option.map (Music.Transposition.from_semitones % Int64.to_int) set_parameter_version_parameter_transposition_semitones)
              ?first_bar: (Option.map Int64.to_int set_parameter_version_parameter_first_bar)
              ?clef: (Option.map Music.Clef.of_string set_parameter_version_parameter_clef)
              ?structure: (Option.map (Option.get % Version_parameters.maybe_structure_of_string % NEString.of_string_exn) set_parameter_version_parameter_structure)
              ?trivia: set_parameter_version_parameter_trivia
              ?display_name: (Option.map NEString.of_string_exn set_parameter_version_parameter_display_name)
              ?display_composer: (Option.map NEString.of_string_exn set_parameter_version_parameter_display_composer)
              ()
          )
          ()
      in
      let dance =
        Option.map
          (fun dance_id ->
            dance_sql_to_row
              ~id: dance_id
              ~name: (Option.get dance_name)
              ~kind: (Option.get dance_kind)
              ~disambiguation: dance_disambiguation
              ~devisers: (dance_devisers_for dance_id)
              ~k: Fun.id
          )
          dance_id
      in
      let set =
        Option.map
          (fun set_id ->
            match set_entity_is_public, (* set_actor_role, *) set_actor_is_omniscient_administrator with
            | None, (* None, *) None -> Forbidden
            | Some set_entity_is_public, (* Some set_actor_role, *) Some set_actor_is_omniscient_administrator ->
              Allowed (
                set_sql_to_row
                  ~id: set_id
                  ~entity_is_public: set_entity_is_public
                  ~actor_role: set_actor_role
                  ~actor_group_id: set_actor_group_id
                  ~actor_group_name: set_actor_group_name
                  ~actor_is_omniscient_administrator: set_actor_is_omniscient_administrator
                  ~name: (Option.get set_name)
                  ~kind: (Option.get set_kind)
                  ~conceptors: (set_conceptors_for set_id)
                  ~tunes: (tunes_for set_id)
                  ~k: Fun.id
              )
            | _ -> assert false
          )
          set_id
      in
      let page =
        match page_type with
        | `Part -> Book_form.Part (NEString.of_string_exn @@ Option.get part_title)
        | `Dance_only -> Dance (Option.get dance, Dance_only)
        | `Dance_versions -> Dance (Option.get dance, Dance_versions (NEList.of_list_exn @@ content_versions_for (book_id, index)))
        | `Dance_set -> Dance (Option.get dance, Dance_set (get_allowed @@ Option.get set, set_params))
        | `Versions -> Versions (NEList.of_list_exn @@ content_versions_for (book_id, index))
        | `Set -> Set (get_allowed @@ Option.get set, set_params)
      in
      k book_id page
    )

let get_row_for ~actor_id ids : (Book_id.t -> Book_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt authors_for = get_authors_for db (`One_of ids) in
  Utils.fold_to_get_single
    (Book_sql.Fold.get_rows db ~ids: (List.map Id.unsafe_coerce ids) ~actor_id)
    (fun k ~id ->
      let id = Id.unsafe_coerce id in
      book_sql_to_row ~id ~authors: (authors_for id) ~k: (k id)
    )

let get_view ~actor_id id : Book_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt authors = (fun f -> f id) <$> get_authors_for db (`One_of [id]) in
  let%lwt sources = (fun f -> f id) <$> get_sources_for db (`One_of [id]) in
  let%lwt contents = (fun f -> f id) <$> get_contents_for ~actor_id db (`One_of [id]) in
  Book_sql.Single.get_view
    db
    ~actor_id
    ~id: (Id.unsafe_coerce id)
    (fun ~id ->
      let id = Id.unsafe_coerce id in
      book_sql_to_view ~id ~authors ~sources ~contents ~k: Fun.id
    )

let get_form ~actor_id id : Book_form.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt authors = (fun f -> f id) <$> get_authors_for db (`One_of [id]) in
  let%lwt sources = (fun f -> f id) <$> get_source_rows_for db (`One_of [id]) in
  let%lwt contents = (fun f -> f id) <$> get_form_contents_for ~actor_id db (`One_of [id]) in
  Book_sql.Single.get_form
    db
    ~actor_id
    ~id
    (book_sql_to_form ~authors ~sources ~contents ~k: Fun.id)

let search ~actor_id query : (Book_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = {Book_query.author; contains_version; contains_tune; contains_set}} = query in
  Connection.with_ @@ fun db ->
  let%lwt authors_for = get_authors_for db `All in
  Book_sql.List.search
    db
    ~actor_id
    ~terms
    ~author: (Utils.option_to_sql author)
    ~contains_version: (Utils.option_to_sql contains_version)
    ~contains_tune: (Utils.option_to_sql contains_tune)
    ~contains_set: (Utils.option_to_sql contains_set)
    (fun ~score ~id ->
      let id = Id.unsafe_coerce id in
      book_sql_to_row
        ~id
        ~authors: (authors_for id)
        ~k: (Pair.snoc score)
    )

let update_other_tables db ~book_id ~authors ~sources ~contents =
  ignore <$> Book_sql.delete_all_authors db ~book_id;%lwt
  Lwt_list.iter_s
    (fun author ->
      ignore
      <$> Book_sql.add_one_author
          db
          ~book_id
          ~author_id: author.Person_row.id
    )
    authors;%lwt
  ignore <$> Book_sql.delete_all_sources db ~book_id;%lwt
  Lwt_list.iter_s
    (fun source ->
      ignore
      <$> Book_sql.add_one_source
          db
          ~book_id
          ~source_id: source.Source_row.id
    )
    sources;%lwt
  ignore <$> Book_sql.delete_all_contents db ~book_id;%lwt
  ignore <$> Book_sql.delete_all_content_versions db ~book_id;%lwt
  Lwt_list.iteri_s
    (fun content_index page ->
      let (page_type, part_title, dance, set, set_params, versions_and_params) =
        match (page : Book_form.page) with
        | Part title -> (`Part, Some title, None, None, Set_parameters.none, [])
        | Dance (dance, Dance_only) -> (`Dance_only, None, Some dance, None, Set_parameters.none, [])
        | Dance (dance, Dance_versions versions_and_params) -> (`Dance_versions, None, Some dance, None, Set_parameters.none, NEList.to_list versions_and_params)
        | Dance (dance, Dance_set (set, set_params)) -> (`Dance_set, None, Some dance, Some set, set_params, [])
        | Versions versions_and_params -> (`Versions, None, None, None, Set_parameters.none, NEList.to_list versions_and_params)
        | Set (set, set_params) -> (`Set, None, None, Some set, set_params, [])
      in
      let set_version_params = Set_parameters.every_version set_params in
      ignore
      <$> Book_sql.add_one_content_item
          db
          ~book_id
          ~index: (Int64.of_int content_index)
          ~page_type
          ~part_title: (Option.map NEString.to_string part_title)
          ~dance_id: (Option.map Dance_row.id dance)
          ~set_id: (Option.map Set_row.id set)
          ~set_parameter_display_name: (Option.map NEString.to_string @@ Set_parameters.display_name set_params)
          ~set_parameter_display_conceptor: (Option.map NEString.to_string @@ Set_parameters.display_conceptor set_params)
          ~set_parameter_display_kind: (Option.map NEString.to_string @@ Set_parameters.display_kind set_params)
          ~set_parameter_version_parameter_transposition_semitones: (Option.map (Int64.of_int % Music.Transposition.to_semitones) @@ Version_parameters.transposition set_version_params)
          ~set_parameter_version_parameter_first_bar: (Option.map Int64.of_int @@ Version_parameters.first_bar set_version_params)
          ~set_parameter_version_parameter_clef: (Option.map Music.Clef.to_string @@ Version_parameters.clef set_version_params)
          ~set_parameter_version_parameter_structure: (Option.map (NEString.to_string % Version_parameters.maybe_structure_to_string) @@ Version_parameters.structure set_version_params)
          ~set_parameter_version_parameter_trivia: (Version_parameters.trivia set_version_params)
          ~set_parameter_version_parameter_display_name: (Option.map NEString.to_string @@ Version_parameters.display_name set_version_params)
          ~set_parameter_version_parameter_display_composer: (Option.map NEString.to_string @@ Version_parameters.display_composer set_version_params);%lwt
      Lwt_list.iteri_s
        (fun index (version, params) ->
          ignore
          <$> Book_sql.add_one_content_version
              db
              ~book_id
              ~content_index: (Int64.of_int content_index)
              ~index: (Int64.of_int index)
              ~version_id: (Version_row.id version)
              ~version_parameter_transposition_semitones: (Option.map (Int64.of_int % Music.Transposition.to_semitones) @@ Version_parameters.transposition params)
              ~version_parameter_first_bar: (Option.map Int64.of_int @@ Version_parameters.first_bar params)
              ~version_parameter_clef: (Option.map Music.Clef.to_string @@ Version_parameters.clef params)
              ~version_parameter_structure: (Option.map (NEString.to_string % Version_parameters.maybe_structure_to_string) @@ Version_parameters.structure params)
              ~version_parameter_trivia: (Version_parameters.trivia params)
              ~version_parameter_display_name: (Option.map NEString.to_string @@ Version_parameters.display_name params)
              ~version_parameter_display_composer: (Option.map NEString.to_string @@ Version_parameters.display_composer params)
        )
        versions_and_params
    )
    contents

let create db ~owner_id book =
  let%lwt id = Entity.make_private db `Book owner_id in
  ignore <$> book_form_to_sql (Book_sql.create db) id book;%lwt
  update_other_tables db ~book_id: id ~authors: book.authors ~sources: book.sources ~contents: book.contents;%lwt
  lwt id

let update db id book =
  Entity.touch db id;%lwt
  ignore <$> book_form_to_sql (fun ~id -> Book_sql.update db ~id) id book;%lwt
  update_other_tables db ~book_id: id ~authors: book.authors ~sources: book.sources ~contents: book.contents

let delete db id =
  ignore <$> Book_sql.delete_all_authors db ~book_id: id;%lwt
  ignore <$> Book_sql.delete_all_content_versions db ~book_id: id;%lwt
  ignore <$> Book_sql.delete_all_contents db ~book_id: id;%lwt
  ignore <$> Book_sql.delete_all_sources db ~book_id: id;%lwt
  ignore <$> Book_sql.delete db ~id;%lwt
  Entity.delete db id
