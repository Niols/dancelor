open Nes
open Dancelor_common
open Model_new
open Search_new
open Sql_to_name
open Sql_to_row
open Sql_to_view

module Entry_sql = Entry_sql.Sqlgg(Sqlgg_postgresql)
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
        Model_builder.Core.Version_parameters.make
          ?transposition: (Option.map (Transposition.from_semitones % Int64.to_int) version_parameter_transposition_semitones)
          ?first_bar: (Option.map Int64.to_int version_parameter_first_bar)
          ?clef: (Option.map Music.Clef.of_string version_parameter_clef)
          ?structure: (Option.map (Option.get % Model_builder.Core.Version_parameters.maybe_structure_of_string % NEString.of_string_exn) version_parameter_structure)
          ?trivia: version_parameter_trivia
          ?display_name: (Option.map NEString.of_string_exn version_parameter_display_name)
          ?display_composer: (Option.map NEString.of_string_exn version_parameter_display_composer)
          ()
      in
      k (book_id, content_index) (version, version_params)
    )

let get_content_for ~user_id db book_ids =
  let%lwt dance_devisers_for = get_dance_devisers_for db book_ids in
  let%lwt tunes_for = get_set_tunes_for db book_ids in
  let%lwt set_conceptors_for = get_set_conceptors_for db book_ids in
  let%lwt content_versions_for = get_content_versions_for db book_ids in
  Utils.fold_to_get_list
    (Book_sql.Fold.get_content_for db ~user_id ~book_ids)
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
        ~set_is_public
        ~set_actor_role
        ~set_user_is_omniscient_administrator
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
        Model_builder.Core.Set_parameters.make
          ?display_name: (Option.map NEString.of_string_exn set_parameter_display_name)
          ?display_conceptor: (Option.map NEString.of_string_exn set_parameter_display_conceptor)
          ?display_kind: (Option.map NEString.of_string_exn set_parameter_display_kind)
          ~every_version: (
            Model_builder.Core.Version_parameters.make
              ?transposition: (Option.map (Transposition.from_semitones % Int64.to_int) set_parameter_version_parameter_transposition_semitones)
              ?first_bar: (Option.map Int64.to_int set_parameter_version_parameter_first_bar)
              ?clef: (Option.map Music.Clef.of_string set_parameter_version_parameter_clef)
              ?structure: (Option.map (Option.get % Model_builder.Core.Version_parameters.maybe_structure_of_string % NEString.of_string_exn) set_parameter_version_parameter_structure)
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
            match set_is_public, (* set_actor_role, *) set_user_is_omniscient_administrator with
            | None, (* None, *) None -> Forbidden
            | Some set_is_public, (* Some set_actor_role, *) Some set_user_is_omniscient_administrator ->
              Allowed (
                set_sql_to_row
                  ~id: set_id
                  ~is_public: set_is_public
                  ~actor_role: set_actor_role
                  ~user_is_omniscient_administrator: set_user_is_omniscient_administrator
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

let get_row_for ~user_id ids : (Book_id.t -> Book_row.t option) Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt authors_for = get_authors_for db (`One_of ids) in
  Utils.fold_to_get_single
    (Book_sql.Fold.get_rows db ~ids ~user_id)
    (fun k ~id -> book_sql_to_row ~id ~authors: (authors_for id) ~k: (k id))

let get_view ~user_id id : Book_view.t option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt authors = (fun f -> f id) <$> get_authors_for db (`One_of [id]) in
  let%lwt sources = (fun f -> f id) <$> get_sources_for db (`One_of [id]) in
  let%lwt content = (fun f -> f id) <$> get_content_for ~user_id db (`One_of [id]) in
  Book_sql.Single.get_view
    db
    ~user_id
    ~id
    (book_sql_to_view ~authors ~sources ~content ~k: Fun.id)

let search ~user_id query : (Book_row.t * float) list Lwt.t =
  let {Query.common = {terms}; specific = {Book_query.author; contains_version; contains_tune; contains_set}} = query in
  Connection.with_ @@ fun db ->
  let%lwt authors_for = get_authors_for db `All in
  Book_sql.List.search
    db
    ~user_id
    ~terms
    ~author: (Utils.option_to_sql author)
    ~contains_version: (Utils.option_to_sql contains_version)
    ~contains_tune: (Utils.option_to_sql contains_tune)
    ~contains_set: (Utils.option_to_sql contains_set)
    (fun ~score ~id ->
      book_sql_to_row
        ~id
        ~authors: (authors_for id)
        ~k: (Pair.snoc score)
    )

(* Legacy *)

type t = Model_builder.Core.Book.t
type entry = Model_builder.Core.Book.entry

let sql_to_book
    ~id
    ~name
    ~date
    ~remark
    ~scddb_id
    ~created_at
    ~modified_at
    ~is_public
    ~authors
    ~sources
    ~content
    ~owners
    ~viewers
  =
  Entry.make
    ~id
    ~meta: (Entry.Meta.make ~created_at ~modified_at ())
    ~access: (Entry.Access.Private.make ~owners ~viewers ~is_public ())
    (
      Model_builder.Core.Book.make
        ~name: (NEString.of_string_exn name)
        ~date: (Option.map (Option.get % PartialDate.from_string) date)
        ~remark: (Option.map NEString.of_string_exn remark)
        ~scddb_id: (Option.map Int64.to_int scddb_id)
        ~authors
        ~sources
        ~contents: content
        ()
    )

let book_to_sql ~create_or_update db id book =
  (* FIXME: transaction, maybe [Connection.with_transaction] *)
  ignore
  <$> create_or_update
      db
      ~id
      ~name: (NEString.to_string @@ Model_builder.Core.Book.name book)
      ~date: (Option.map PartialDate.to_string @@ Model_builder.Core.Book.date book)
      ~remark: (Option.map NEString.to_string @@ Model_builder.Core.Book.remark book)
      ~scddb_id: (Option.map Int64.of_int @@ Model_builder.Core.Book.scddb_id book);%lwt
  ignore <$> Book_sql.delete_all_authors db ~book_id: id;%lwt
  Lwt_list.iter_s
    (fun author ->
      ignore
      <$> Book_sql.add_one_author
          db
          ~book_id: id
          ~author_id: author
    )
    (Model_builder.Core.Book.authors book);%lwt
  ignore <$> Book_sql.delete_all_sources db ~book_id: id;%lwt
  Lwt_list.iter_s
    (fun source ->
      ignore
      <$> Book_sql.add_one_source
          db
          ~book_id: id
          ~source_id: source
    )
    (Model_builder.Core.Book.sources book);%lwt
  ignore <$> Book_sql.delete_all_content db ~book_id: id;%lwt
  ignore <$> Book_sql.delete_all_content_versions db ~book_id: id;%lwt
  Lwt_list.iteri_s
    (fun content_index page ->
      let (page_type, part_title, dance_id, set_id, set_params, versions_and_params) =
        match (page : Model_builder.Core.Book.page) with
        | Part title -> (`Part, Some title, None, None, Model_builder.Core.Set_parameters.none, [])
        | Dance (dance, Dance_only) -> (`Dance_only, None, Some dance, None, Model_builder.Core.Set_parameters.none, [])
        | Dance (dance, Dance_versions versions_and_params) -> (`Dance_versions, None, Some dance, None, Model_builder.Core.Set_parameters.none, NEList.to_list versions_and_params)
        | Dance (dance, Dance_set (set, set_params)) -> (`Dance_set, None, Some dance, Some set, set_params, [])
        | Versions versions_and_params -> (`Versions, None, None, None, Model_builder.Core.Set_parameters.none, NEList.to_list versions_and_params)
        | Set (set, set_params) -> (`Set, None, None, Some set, set_params, [])
      in
      let set_version_params = Model_builder.Core.Set_parameters.every_version set_params in
      ignore
      <$> Book_sql.add_one_content_item
          db
          ~book_id: id
          ~index: (Int64.of_int content_index)
          ~page_type
          ~part_title: (Option.map NEString.to_string part_title)
          ~dance_id
          ~set_id
          ~set_parameter_display_name: (Option.map NEString.to_string @@ Model_builder.Core.Set_parameters.display_name set_params)
          ~set_parameter_display_conceptor: (Option.map NEString.to_string @@ Model_builder.Core.Set_parameters.display_conceptor set_params)
          ~set_parameter_display_kind: (Option.map NEString.to_string @@ Model_builder.Core.Set_parameters.display_kind set_params)
          ~set_parameter_version_parameter_transposition_semitones: (Option.map (Int64.of_int % Transposition.to_semitones) @@ Model_builder.Core.Version_parameters.transposition set_version_params)
          ~set_parameter_version_parameter_first_bar: (Option.map Int64.of_int @@ Model_builder.Core.Version_parameters.first_bar set_version_params)
          ~set_parameter_version_parameter_clef: (Option.map Music.Clef.to_string @@ Model_builder.Core.Version_parameters.clef set_version_params)
          ~set_parameter_version_parameter_structure: (Option.map (NEString.to_string % Model_builder.Core.Version_parameters.maybe_structure_to_string) @@ Model_builder.Core.Version_parameters.structure set_version_params)
          ~set_parameter_version_parameter_trivia: (Model_builder.Core.Version_parameters.trivia set_version_params)
          ~set_parameter_version_parameter_display_name: (Option.map NEString.to_string @@ Model_builder.Core.Version_parameters.display_name set_version_params)
          ~set_parameter_version_parameter_display_composer: (Option.map NEString.to_string @@ Model_builder.Core.Version_parameters.display_composer set_version_params);%lwt
      Lwt_list.iteri_s
        (fun index (version, params) ->
          ignore
          <$> Book_sql.add_one_content_version
              db
              ~book_id: id
              ~content_index: (Int64.of_int content_index)
              ~index: (Int64.of_int index)
              ~version_id: version
              ~version_parameter_transposition_semitones: (Option.map (Int64.of_int % Transposition.to_semitones) @@ Model_builder.Core.Version_parameters.transposition params)
              ~version_parameter_first_bar: (Option.map Int64.of_int @@ Model_builder.Core.Version_parameters.first_bar params)
              ~version_parameter_clef: (Option.map Music.Clef.to_string @@ Model_builder.Core.Version_parameters.clef params)
              ~version_parameter_structure: (Option.map (NEString.to_string % Model_builder.Core.Version_parameters.maybe_structure_to_string) @@ Model_builder.Core.Version_parameters.structure params)
              ~version_parameter_trivia: (Model_builder.Core.Version_parameters.trivia params)
              ~version_parameter_display_name: (Option.map NEString.to_string @@ Model_builder.Core.Version_parameters.display_name params)
              ~version_parameter_display_composer: (Option.map NEString.to_string @@ Model_builder.Core.Version_parameters.display_composer params)
        )
        versions_and_params
    )
    (Model_builder.Core.Book.contents book)

let sql_to_content_version ~k = fun
    ~version_id
    ~version_parameter_transposition_semitones
    ~version_parameter_first_bar
    ~version_parameter_clef
    ~version_parameter_structure
    ~version_parameter_trivia
    ~version_parameter_display_name
    ~version_parameter_display_composer
  ->
  k
    (
      version_id,
      Model_builder.Core.Version_parameters.make
        ?transposition: (Option.map (Transposition.from_semitones % Int64.to_int) version_parameter_transposition_semitones)
        ?first_bar: (Option.map Int64.to_int version_parameter_first_bar)
        ?clef: (Option.map Music.Clef.of_string version_parameter_clef)
        ?structure: (Option.map (Option.get % Model_builder.Core.Version_parameters.maybe_structure_of_string % NEString.of_string_exn) version_parameter_structure)
        ?trivia: version_parameter_trivia
        ?display_name: (Option.map NEString.of_string_exn version_parameter_display_name)
        ?display_composer: (Option.map NEString.of_string_exn version_parameter_display_composer)
        ()
    )

let sql_to_content_item ~versions_and_params ~k = fun
    ~page_type
    ~part_title
    ~dance_id
    ~set_id
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
    Model_builder.Core.Set_parameters.make
      ?display_name: (Option.map NEString.of_string_exn set_parameter_display_name)
      ?display_conceptor: (Option.map NEString.of_string_exn set_parameter_display_conceptor)
      ?display_kind: (Option.map NEString.of_string_exn set_parameter_display_kind)
      ~every_version: (
        Model_builder.Core.Version_parameters.make
          ?transposition: (Option.map (Transposition.from_semitones % Int64.to_int) set_parameter_version_parameter_transposition_semitones)
          ?first_bar: (Option.map Int64.to_int set_parameter_version_parameter_first_bar)
          ?clef: (Option.map Music.Clef.of_string set_parameter_version_parameter_clef)
          ?structure: (Option.map (Option.get % Model_builder.Core.Version_parameters.maybe_structure_of_string % NEString.of_string_exn) set_parameter_version_parameter_structure)
          ?trivia: set_parameter_version_parameter_trivia
          ?display_name: (Option.map NEString.of_string_exn set_parameter_version_parameter_display_name)
          ?display_composer: (Option.map NEString.of_string_exn set_parameter_version_parameter_display_composer)
          ()
      )
      ()
  in
  k @@
    match page_type with
    | `Part -> Model_builder.Core.Book.Part (NEString.of_string_exn @@ Option.get part_title)
    | `Dance_only -> Dance (Option.get dance_id, Dance_only)
    | `Dance_versions -> Dance (Option.get dance_id, Dance_versions (NEList.of_list_exn versions_and_params))
    | `Dance_set -> Dance (Option.get dance_id, Dance_set (Option.get set_id, set_params))
    | `Versions -> Versions (NEList.of_list_exn versions_and_params)
    | `Set -> Set (Option.get set_id, set_params)
    | _ -> assert false

let get id : Model_builder.Core.Book.entry option Lwt.t =
  Connection.with_ @@ fun db ->
  let%lwt authors = Book_sql.List.get_authors db ~book_id: id (fun ~author_id -> author_id) in
  let%lwt sources = Book_sql.List.get_sources db ~book_id: id (fun ~source_id -> source_id) in
  let%lwt (owners, viewers) =
    List.partition_map (function (`Owner, user_id) -> Left user_id | (`Viewer, user_id) -> Right user_id)
    <$> Entry_sql.List.get_actors db ~entry_id: id (fun ~user_id ~role -> (role, user_id))
  in
  let content_versions = Hashtbl.create 8 in
  Book_sql.Fold.get_content_versions db ~book_id: id (fun ~content_index -> sql_to_content_version ~k: (fun v () -> Hashtbl.add content_versions content_index v)) ();%lwt
  let%lwt content = Book_sql.List.get_content db ~book_id: id (fun ~index -> sql_to_content_item ~versions_and_params: (List.rev @@ Hashtbl.find_all content_versions index) ~k: Fun.id) in
  Book_sql.Single.get db ~id (sql_to_book ~id ~authors ~sources ~viewers ~owners ~content)

let create book access =
  Connection.with_ @@ fun db ->
  let%lwt id = Entry_new.make_private db `Book access in
  book_to_sql ~create_or_update: Book_sql.create db id book;%lwt
  lwt id

let update id book access =
  Connection.with_ @@ fun db ->
  Entry_new.touch db id;%lwt
  Entry_new.update_private_access db id access;%lwt
  book_to_sql ~create_or_update: (fun db ~id -> Book_sql.update db ~id) db id book

let delete id =
  Connection.with_ @@ fun db ->
  ignore <$> Book_sql.delete_all_authors db ~book_id: id;%lwt
  ignore <$> Book_sql.delete_all_content_versions db ~book_id: id;%lwt
  ignore <$> Book_sql.delete_all_content db ~book_id: id;%lwt
  ignore <$> Book_sql.delete_all_sources db ~book_id: id;%lwt
  ignore <$> Book_sql.delete db ~id;%lwt
  Entry_new.delete db id
