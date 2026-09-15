(** {1 Conversion from models to renderer}

    This module contains the logic to convert from {!Dancelor_common.Model} to
    {!Renderer}. It is meant to be used in other controllers. *)

open NesUnix
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.model_to_renderer": Logs.LOG)

let format_persons_list =
  List.map (NEString.to_string % Model.Person.name')

let format_persons =
  String.concat ", " ~last: " and " % format_persons_list

let version_to_lilypond_content ~version_params version =
  (* get a LilyPond from the potentially-destructured content *)
  let structure =
    match Model.Version_parameters.structure version_params with
    | Some Force_no_structure -> None
    | Some Structure structure -> Some structure
    | None ->
      match Model.Version.content version with
      | No_content -> None
      | Monolithic {structure; _} -> Some structure
      | Destructured {default_structure; _} -> Some default_structure
  in
  match%lwt Model.Version.content_lilypond ?structure version with
  | None -> lwt_none
  | Some content ->
    let instructions =
      (* if the version is destructured, and the user asked for a structure, but
         we could not find a fold for this structure, then at least we produce the
         instruction to play that structure as we generate a destructured output *)
      match Model.Version.content version with
      | No_content -> None
      | Monolithic _ -> None
      | Destructured _ ->
        match structure with
        | None -> None
        | Some structure ->
          match Model.Version.Structure.best_fold_for structure with
          | Some _ -> None
          | None -> Some ("Play " ^ NEString.to_string (Model.Version.Structure.to_string structure))
    in
    (* update the clef *)
    let content =
      match Model.Version_parameters.clef version_params with
      | None -> content
      | Some clef_parameter ->
        let clef_regex = Str.regexp "\\\\clef *\"?[a-z]*\"?" in
        Str.global_replace clef_regex ("\\clef " ^ Music.Clef.to_string clef_parameter) content
    in
    (* add transposition *)
    let content =
      let source = Music.Key.pitch @@ Model.Version.key version in
      let target = Transposition.target_pitch ~source @@ Option.value ~default: Transposition.identity @@ Model.Version_parameters.transposition version_params in
      let (source, target) = Pair.map_both Music.Pitch.to_lilypond_string (source, target) in
      spf "\\transpose %s %s { %s }" source target content
    in
    (* done *)
    lwt_some (content, instructions)

let version_to_renderer_tune ?(version_params = Model.Version_parameters.none) version =
  let%lwt slug = NesSlug.to_string <$> Model.Version.slug version in
  let%lwt name =
    let%lwt default = Model.Version.one_name version in
    lwt @@
    NEString.to_string @@
    Option.value
      ~default
      (Model.Version_parameters.display_name version_params)
  in
  let%lwt composer =
    let%lwt none =
      (
        format_persons
        <%> (Lwt_list.map_p (Option.get <%> Model.Person.get % Model.Tune.composer_composer) % Model.Tune.composers')
      )
      =<< (Model.Version.tune version)
    in
    lwt @@
      Option.fold
        ~none
        ~some: NEString.to_string
        (Model.Version_parameters.display_composer version_params)
  in
  let%lwt (content, instructions) =
    match%lwt version_to_lilypond_content ~version_params version with
    | Some (content, instructions) -> lwt (content, Option.value instructions ~default: "")
    | None -> lwt ("", "")
  in
  let first_bar = Model.Version_parameters.first_bar' version_params in
  let%lwt tune = Model.Version.tune version in
  let kind = Model.Tune.kind' tune in
  let (tempo_unit, tempo_value) =
    match kind with
    | Jig | March_6_8 -> ("4.", 104)
    | Reel | Hornpipe | Polka | March_2_4 | March_4_4 ->
      let as_2_4 =
        match Model.Version.content version with
        | No_content | Monolithic _ -> false
        | Destructured {as_2_4; _} -> as_2_4
      in
        ((if as_2_4 then "4" else "2"), 108)
    | Jig_9_8 -> ("4.", 104)
    | Strathspey | Air | Schottische -> ("2", 60)
    | Two_step -> ("4", 130)
    | Waltz -> ("2.", 60)
    | Other -> ("2", 108)
  in
  let chords_kind =
    match kind with
    | Jig | March_6_8 -> "jig"
    | Reel | Hornpipe | Polka | March_2_4 | March_4_4 -> "reel"
    | Air | Strathspey | Schottische | Two_step -> "strathspey"
    | Waltz -> "waltz"
    | Other | Jig_9_8 -> "other"
  in
  let show_bar_numbers =
    Model.Version.(Content.is_monolithic @@ content version)
    || Model.Version_parameters.structure version_params <> Some Force_no_structure
  in
  let show_time_signatures = kind = Other in
  (* only show time signatures if “Other” *)
  lwt Renderer.{slug; name; instructions; composer; content; first_bar; tempo_unit; tempo_value; chords_kind; show_bar_numbers; show_time_signatures}

let version_to_renderer_tune' ?version_params version =
  version_to_renderer_tune ?version_params (Entry.value version)

let part_to_renderer_part name =
  Renderer.{name = NEString.to_string name}

let set_to_renderer_set set set_params : (Renderer.set * Renderer.pdf_metadata) Lwt.t =
  let name = NEString.to_string @@ Option.value (Model.Set_parameters.display_name set_params) ~default: (Model.Set.name set) in
  let%lwt conceptors = Lwt_list.map_p (Option.get <%> Model.Person.get) (Model.Set.conceptors set) in
  let%lwt renderer_set =
    let slug = NesSlug.to_string @@ Model.Set.slug set in
    let%lwt conceptor =
      lwt @@
        match Model.Set_parameters.display_conceptor set_params, conceptors with
        | None, [] -> ""
        | None, _ -> "Set by " ^ format_persons conceptors
        | Some conceptor, [] -> NEString.to_string conceptor
        | Some conceptor, _ -> NEString.to_string conceptor ^ ", set by " ^ format_persons conceptors
    in
    let kind =
      let none = Kind.Dance.to_pretty_string @@ Model.Set.kind set in
      let kind = Option.fold ~none ~some: NEString.to_string (Model.Set_parameters.display_kind set_params) in
      match Model.Set.order set with
      | [] -> kind
      | order -> kind ^ " — Play " ^ Model.Set_order.to_pretty_string order
    in
    let every_version_params = Model.Set_parameters.every_version set_params in
    let%lwt contents =
      Lwt_list.map_s
        (fun (version, version_params) ->
          let%lwt version = Option.get <$> Model.Version.get version in
          let version_params = Model.Version_parameters.compose every_version_params version_params in
          version_to_renderer_tune' version ~version_params
        )
        (Model.Set.contents set)
    in
    lwt Renderer.{slug; name; conceptor; kind; contents}
  in
  let pdf_metadata =
    let subjects =
      match Kind.Dance.to_simple @@ Model.Set.kind set with
      | None -> ["Medley"]
      | Some (n, bars, base) -> [Kind.Base.to_long_string ~capitalised: true base; spf "%dx%d" n bars]
    in
      {Renderer.title = name; authors = format_persons_list conceptors; subjects}
  in
  lwt (renderer_set, pdf_metadata)

let set_to_renderer_set' set set_params =
  let%lwt set = Entry.value % Option.get <$> Model.Set.get set in
  set_to_renderer_set set set_params

let versions_to_renderer_set versions_and_params set_params =
  let%lwt name =
    let%lwt name = String.concat ", " ~last: " and " <$> Lwt_list.map_s (NEString.to_string <%> Model.Version.one_name % fst) (NEList.to_list versions_and_params) in
    lwt @@ Option.fold ~none: name ~some: NEString.to_string (Model.Set_parameters.display_name set_params)
  in
  let%lwt renderer_set =
    let slug = NesSlug.(to_string % of_string) name in
    let conceptor =
      Option.fold ~none: "" ~some: NEString.to_string (Model.Set_parameters.display_conceptor set_params)
    in
    let kind =
      Option.fold ~none: "" ~some: NEString.to_string (Model.Set_parameters.display_kind set_params)
    in
    let%lwt contents =
      Lwt_list.map_s (fun (version, version_params) -> version_to_renderer_tune version ~version_params) (NEList.to_list versions_and_params)
    in
    lwt {Renderer.slug; name; conceptor; kind; contents}
  in
  let pdf_metadata =
    {Renderer.title = name; authors = []; subjects = []}
  in
  lwt (renderer_set, pdf_metadata)

let versions_to_renderer_set' versions_and_params set_params =
  let%lwt versions_and_params =
    Monadise_lwt.run @@ fun () ->
    NEList.map (Pair.map_fst (Entry.value % Option.get % Monadise_lwt.yield % Model.Version.get)) versions_and_params
  in
  versions_to_renderer_set versions_and_params set_params

let dance_to_renderer_set set_params =
  set_to_renderer_set
    (
      Model.Set.make
        ~name: (NEString.of_string_exn "should not be seen")
        ~kind: (Version (0, Reel))
        ~order: []
        ~conceptors: []
        ~contents: []
        ~remark: None
        ()
    )
    set_params

let page_to_renderer_page page book_params : (Renderer.page * Renderer.pdf_metadata) Lwt.t =
  let every_set_params = Model.Book_parameters.every_set book_params in
  match page with
  | Model.Book.Part title ->
    lwt (Renderer.Part (part_to_renderer_part title), {Renderer.title = NEString.to_string title; authors = []; subjects = []})
  | Model.Book.Dance (dance, dance_page) ->
    (
      let%lwt dance = Option.get <$> Model.Dance.get dance in
      let%lwt dance_params =
        let display_name = Model.Dance.one_name' dance in
        let%lwt display_conceptor =
          let%lwt devisers = Lwt_list.map_p (Option.get <%> Model.Person.get) (Model.Dance.devisers' dance) in
          lwt @@
          NEString.of_string_exn @@
          match devisers with
          | [] -> " "
          | _ -> "Dance by " ^ format_persons devisers
        in
        let display_kind =
          NEString.of_string_exn @@
          (Kind.Dance.to_pretty_string @@ Model.Dance.kind' dance) ^ (
            match Model.Dance.two_chords' dance with
            | Dont_know -> " — Two chords: unknown"
            | One_chord -> ""
            | Two_chords -> " — Two chords"
          )
        in
        lwt @@ Model.Set_parameters.make ~display_name ~display_conceptor ~display_kind ()
      in
      let dance_params =
        Model.Set_parameters.compose every_set_params dance_params
      in
      match dance_page with
      | Dance_only ->
        Pair.map_fst Renderer.set <$> dance_to_renderer_set dance_params
      | Dance_versions versions_and_params ->
        Pair.map_fst Renderer.set <$> versions_to_renderer_set' versions_and_params dance_params
      | Dance_set (set, set_params) ->
        let set_params = Model.Set_parameters.compose set_params dance_params in
        Pair.map_fst Renderer.set <$> set_to_renderer_set' set set_params
    )
  | Model.Book.Versions versions_and_params ->
    Pair.map_fst Renderer.set <$> versions_to_renderer_set' versions_and_params every_set_params
  | Model.Book.Set (set, set_params) ->
    let set_params = Model.Set_parameters.compose set_params every_set_params in
    Pair.map_fst Renderer.set <$> set_to_renderer_set' set set_params

let book_to_renderer_book book book_params : (Renderer.book * Renderer.pdf_metadata) Lwt.t =
  let name = NEString.to_string @@ Model.Book.name book in
  let%lwt editors = Lwt_list.map_p (Option.get <%> Model.Person.get) (Model.Book.authors book) in
  let%lwt renderer_book =
    let slug = NesSlug.to_string @@ Model.Book.slug book in
    let editor = format_persons editors in
    let%lwt contents = Lwt_list.map_s (fun page -> fst <$> page_to_renderer_page page book_params) (Model.Book.contents book) in
    let simple = Option.value ~default: false @@ Model.Book_parameters.simple book_params in
    lwt {Renderer.slug; name; editor; contents; simple}
  in
  let pdf_metadata =
    {Renderer.title = name; authors = format_persons_list editors; subjects = []}
  in
  lwt (renderer_book, pdf_metadata)

let book_to_renderer_book' book book_params =
  book_to_renderer_book (Entry.value book) book_params

let grab_renderer_book_pdf_args rendering_params =
  let specificity =
    String.concat ", " ~last: " and " @@
      List.flatten
        [
          Option.to_list (Rendering_parameters.instruments rendering_params);
          Option.to_list (Rendering_parameters.clef rendering_params);
        ]
  in
  let headers = Option.value ~default: true @@ Rendering_parameters.show_headers rendering_params in
    (specificity, headers)

let renderer_book_to_renderer_book_pdf_arg ((book : Renderer.book), pdf_metadata) rendering_params =
  let (specificity, headers) = grab_renderer_book_pdf_args rendering_params in
    ({book; specificity; headers; pdf_metadata}: Renderer.book_pdf_arg)

let renderer_set_to_renderer_set_pdf_arg ((set : Renderer.set), pdf_metadata) rendering_params =
  let (specificity, headers) = grab_renderer_book_pdf_args rendering_params in
    ({set; specificity; headers; pdf_metadata}: Renderer.set_pdf_arg)

let renderer_sets_to_renderer_sets_zip_arg (sets : Renderer.sets_zip_arg_set NEList.t) rendering_params =
  let (specificity, headers) = grab_renderer_book_pdf_args rendering_params in
    ({sets; specificity; headers}: Renderer.sets_zip_arg)
