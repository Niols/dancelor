(** {1 Conversion from models to renderer}

    This module contains the logic to convert from {!Dancelor_common.Model} to
    {!Renderer}. It is meant to be used in other controllers. *)

open Nes_unix
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "server.controller.model_to_renderer": Logs.LOG)

let format_persons_list =
  List.map Person_row.name

let format_persons =
  String.concat ", " ~last: " and " % format_persons_list

let version_to_lilypond_content ~version_params version =
  let {Version_form.tune = {kind; _}; key; content; _} = version in
  (* get a LilyPond from the potentially-destructured content *)
  let structure =
    match Version_parameters.structure version_params with
    | Some Force_no_structure -> None
    | Some Structure structure -> Some structure
    | None ->
      match content with
      | No_content -> None
      | Monolithic {structure; _} -> Some structure
      | Destructured {default_structure; _} -> Some default_structure
  in
  match Version_content.lilypond ?structure ~kind ~key content with
  | None -> None
  | Some lilypond ->
    let instructions =
      (* if the version is destructured, and the user asked for a structure, but
         we could not find a fold for this structure, then at least we produce the
         instruction to play that structure as we generate a destructured output *)
      match content with
      | No_content -> None
      | Monolithic _ -> None
      | Destructured _ ->
        match structure with
        | None -> None
        | Some structure ->
          match Version_content.Structure.best_fold_for structure with
          | Some _ -> None
          | None -> Some ("Play " ^ NEString.to_string (Version_content.Structure.to_string structure))
    in
    (* update the clef *)
    let lilypond =
      match Version_parameters.clef version_params with
      | None -> lilypond
      | Some clef_parameter ->
        let clef_regex = Str.regexp "\\\\clef *\"?[a-z]*\"?" in
        Str.global_replace clef_regex ("\\clef " ^ Music.Clef.to_string clef_parameter) lilypond
    in
    (* add transposition *)
    let lilypond =
      let source = Music.Key.pitch key in
      let target = Music.Transposition.target_pitch ~source @@ Option.value ~default: Music.Transposition.identity @@ Version_parameters.transposition version_params in
      let (source, target) = Pair.map_both Music.Pitch.to_lilypond_string (source, target) in
      spf "\\transpose %s %s { %s }" source target lilypond
    in
    (* done *)
    Some (lilypond, instructions)

let version_to_renderer_tune ?(version_params = Version_parameters.none) version =
  let {Version_form.tune = {name; kind; composers; _}; content; _} = version in
  let name = Option.fold ~none: name ~some: NEString.to_string (Version_parameters.display_name version_params) in
  let slug = NesSlug.to_string @@ NesSlug.of_string name in
  let composer =
    Option.fold
      ~none: (format_persons composers)
      ~some: NEString.to_string
      (Version_parameters.display_composer version_params)
  in
  let (lilypond, instructions) =
    match version_to_lilypond_content ~version_params version with
    | Some (lilypond, instructions) -> (lilypond, Option.value instructions ~default: "")
    | None -> ("", "")
  in
  let first_bar = Version_parameters.first_bar' version_params in
  let (tempo_unit, tempo_value) =
    match kind with
    | Jig | March_6_8 -> ("4.", 104)
    | Reel | Hornpipe | Polka | March_2_4 | March_4_4 ->
      let as_2_4 =
        match content with
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
    Version_content.is_monolithic content
    || Version_parameters.structure version_params <> Some Force_no_structure
  in
  let show_time_signatures = kind = Other in
  (* only show time signatures if “Other” *)
  Renderer.{slug; name; instructions; composer; content = lilypond; first_bar; tempo_unit; tempo_value; chords_kind; show_bar_numbers; show_time_signatures}

let part_to_renderer_part name =
  Renderer.{name = NEString.to_string name}

let set_to_renderer_set (set : Set_form.t) set_params : (Renderer.set * Renderer.pdf_metadata) Lwt.t =
  let name = NEString.to_string @@ Option.value (Set_parameters.display_name set_params) ~default: set.name in
  let%lwt renderer_set =
    let slug = NesSlug.(to_string % of_string) name in
    let%lwt conceptor =
      lwt @@
        match Set_parameters.display_conceptor set_params, set.conceptors with
        | None, [] -> ""
        | None, _ -> "Set by " ^ format_persons set.conceptors
        | Some conceptor, [] -> NEString.to_string conceptor
        | Some conceptor, _ -> NEString.to_string conceptor ^ ", set by " ^ format_persons set.conceptors
    in
    let kind =
      let none = Kind.Dance.to_pretty_string set.kind in
      let kind = Option.fold ~none ~some: NEString.to_string (Set_parameters.display_kind set_params) in
      match set.order with
      | [] -> kind
      | order -> kind ^ " — Play " ^ Set_order.to_pretty_string order
    in
    let every_version_params = Set_parameters.every_version set_params in
    let%lwt contents =
      Lwt_list.map_s
        (fun (version, version_params) ->
          let%lwt version = Option.get <$> Database.Version.get_form version.Version_row.id in
          let version_params = Version_parameters.compose every_version_params version_params in
          lwt @@ version_to_renderer_tune version ~version_params
        )
        set.contents
    in
    lwt Renderer.{slug; name; conceptor; kind; contents}
  in
  let pdf_metadata =
    let subjects =
      match Kind.Dance.to_simple set.kind with
      | None -> ["Medley"]
      | Some (n, bars, base) -> [Kind.Base.to_long_string ~capitalised: true base; spf "%dx%d" n bars]
    in
      {Renderer.title = name; authors = format_persons_list set.conceptors; subjects}
  in
  lwt (renderer_set, pdf_metadata)

let versions_to_renderer_set versions_and_params set_params =
  let name =
    let name = String.concat ", " ~last: " and " @@ List.map (Tune_row.name % Version_form.tune % fst) (NEList.to_list versions_and_params) in
    Option.fold ~none: name ~some: NEString.to_string (Set_parameters.display_name set_params)
  in
  let renderer_set =
    let slug = NesSlug.(to_string % of_string) name in
    let conceptor =
      Option.fold ~none: "" ~some: NEString.to_string (Set_parameters.display_conceptor set_params)
    in
    let kind =
      Option.fold ~none: "" ~some: NEString.to_string (Set_parameters.display_kind set_params)
    in
    let contents =
      List.map (fun (version, version_params) -> version_to_renderer_tune version ~version_params) (NEList.to_list versions_and_params)
    in
      {Renderer.slug; name; conceptor; kind; contents}
  in
  let pdf_metadata =
    {Renderer.title = name; authors = []; subjects = []}
  in
    (renderer_set, pdf_metadata)

let dance_to_renderer_set set_params =
  set_to_renderer_set
    {
      Set_form.name =
      NEString.of_string_exn "should not be seen";
      kind = Version (0, Reel);
      order = [];
      conceptors = [];
      contents = [];
    }
    set_params

let page_to_renderer_page ~actor_id (page : Book_form.page) book_params : (Renderer.page * Renderer.pdf_metadata) Lwt.t =
  let every_set_params = Book_parameters.every_set book_params in
  match page with
  | Part title ->
    lwt (Renderer.Part (part_to_renderer_part title), {Renderer.title = NEString.to_string title; authors = []; subjects = []})
  | Dance (dance, dance_page) ->
    (
      let%lwt (dance : Dance_form.t) = Option.get <$> Database.Dance.get_form dance.id in
      let%lwt dance_params =
        let display_name = NEList.hd dance.names in
        let display_conceptor =
          NEString.of_string_exn @@
            match dance.devisers with
            | [] -> " "
            | _ -> "Dance by " ^ format_persons dance.devisers
        in
        let display_kind =
          NEString.of_string_exn @@
          (Kind.Dance.to_pretty_string dance.kind) ^ (
            match dance.two_chords with
            | Dont_know -> " — Two chords: unknown"
            | One_chord -> ""
            | Two_chords -> " — Two chords"
          )
        in
        lwt @@ Set_parameters.make ~display_name ~display_conceptor ~display_kind ()
      in
      let dance_params =
        Set_parameters.compose every_set_params dance_params
      in
      match dance_page with
      | Dance_only ->
        Pair.map_fst Renderer.set <$> dance_to_renderer_set dance_params
      | Dance_versions versions_and_params ->
        let%lwt versions_and_params =
          Monadise_lwt.lift_1_1
            NEList.map
            (fun (version, params) ->
              let%lwt version = Option.get <$> Database.Version.get_form version.Version_row.id in
              lwt (version, params)
            )
            versions_and_params
        in
        lwt @@ Pair.map_fst Renderer.set @@ versions_to_renderer_set versions_and_params dance_params
      | Dance_set (set, set_params) ->
        let%lwt set = Option.get <$> Database.Set.get_form ~actor_id set.Set_row.id in
        let set_params = Set_parameters.compose set_params dance_params in
        Pair.map_fst Renderer.set <$> set_to_renderer_set set set_params
    )
  | Versions versions_and_params ->
    let%lwt versions_and_params =
      Monadise_lwt.lift_1_1
        NEList.map
        (fun (version, params) ->
          let%lwt version = Option.get <$> Database.Version.get_form version.Version_row.id in
          lwt (version, params)
        )
        versions_and_params
    in
    lwt @@ Pair.map_fst Renderer.set @@ versions_to_renderer_set versions_and_params every_set_params
  | Set (set, set_params) ->
    let%lwt set = Option.get <$> Database.Set.get_form ~actor_id set.Set_row.id in
    let set_params = Set_parameters.compose set_params every_set_params in
    Pair.map_fst Renderer.set <$> set_to_renderer_set set set_params

let book_to_renderer_book ~actor_id (book : Book_form.t) book_params : (Renderer.book * Renderer.pdf_metadata) Lwt.t =
  let name = NEString.to_string book.name in
  let%lwt renderer_book =
    let slug = NesSlug.(to_string % of_string) name in
    let editor = format_persons book.authors in
    let%lwt contents = Lwt_list.map_s (fun page -> fst <$> page_to_renderer_page ~actor_id page book_params) book.contents in
    let simple = Option.value ~default: false @@ Book_parameters.simple book_params in
    lwt {Renderer.slug; name; editor; contents; simple}
  in
  let pdf_metadata =
    {Renderer.title = name; authors = format_persons_list book.authors; subjects = []}
  in
  lwt (renderer_book, pdf_metadata)

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
