open Nes
open Dancelor_common
open Html

let details content = span ~a: [a_class ["opacity-50"]] content

let switch_signal_option = function
  | None -> S.Option.none
  | Some signal -> S.Option.some signal

let several f versions =
  versions
  |> List.map (List.singleton % f)
  |> List.interspersei ~last: (fun _ -> [txt " and "]) (fun _ -> [txt ", "])
  |> List.flatten
  |> span

let several' f versions =
  versions
  |> List.map (List.singleton % f)
  |> List.interspersei ~last: (fun _ -> [[txt " and "]]) (fun _ -> [[txt ", "]])
  |> List.flatten
  |> List.flatten
  |> span

module Person = struct
  let name ?(link = true) ?in_search (person : Person_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_person ?in_search person.id) (switch_signal_option in_search)]
        [txt person.name]
    else
      txt person.name

  let names ?(short = false) ?links (persons : Person_name.t list) =
    let persons = List.map (name ?link: links) persons in
    if short then
      match persons with
      | [] -> []
      | [p] -> [p]
      | [p; q] -> [p; txt " & "; q]
      | p :: _ -> [p; txt " et al."]
    else
      List.interspersei (fun _ -> txt ", ") ~last: (fun _ -> txt " and ") persons

  let names_with_details ?links (persons : Person_name_with_details.t list) =
    persons
    |> List.map (fun person ->
        (name ?link: links @@ Person_name_with_details.to_name person) ::
          (match person.details with None -> [] | Some details -> [txtf " (%s)" details])
      )
    |> List.interspersei (fun _ -> [txt ", "]) ~last: (fun _ -> [txt " and "])
    |> List.flatten
end

module Source = struct
  let name ?(link = true) ?in_search (source : Source_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_source ?in_search source.id) (switch_signal_option in_search)]
        [txt source.name]
    else
      txt source.name

  let name_row ?link ?in_search source =
    name ?link ?in_search (Source_row.to_name source)

  let short_name ?(link = true) ?in_search (source : Source_short_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_source ?in_search source.id) (switch_signal_option in_search)]
        [txt source.short_name]
    else
      txt source.short_name

  let date_and_editors (source : Source_view.t) =
    let date =
      match source.date with
      | None -> []
      | Some date -> [txt (spf "Published %s" (Partial_date.to_pretty_string ~at: true date))]
    in
    let editors =
      match source.editors with
      | [] -> []
      | editors -> (txt "by ") :: Person.names editors
    in
      (date @ [txt " "] @ editors)
end

module Dance = struct
  let name ?(link = true) ?in_search (dance : Dance_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_dance ?in_search dance.id) (switch_signal_option in_search)]
        [txt dance.name]
    else
      txt dance.name

  let name_row ?link ?in_search dance = name ?link ?in_search (Dance_row.to_name dance)

  let name_and_disambiguation ?link ?in_search (dance : Dance_row.t) =
    let disambiguation_block =
      match dance.disambiguation with
      | None -> []
      | Some disambiguation -> [span ~a: [a_class ["opacity-50"]] [txtf " (%s)" disambiguation]]
    in
    name_row ?link ?in_search dance :: disambiguation_block

  let aka (dance : Dance_view.t) =
    match dance.extra_names with
    | [] -> []
    | names -> [txt @@ spf "Also known as %s" @@ String.concat ", " names]

  let description (dance : Dance_view.t) =
    let kind = Kind.Dance.to_pretty_string dance.kind in
    match dance.devisers with
    | [] -> [txt kind]
    | devisers -> (txtf "%s by " kind) :: Person.names devisers
end

module Tune = struct
  let name ?(link = true) ?in_search (tune : Tune_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_tune ?in_search tune.id) (switch_signal_option in_search)]
        [txt tune.name]
    else
      txt tune.name

  let name_row ?link ?in_search (tune : Tune_row.t) = name ?link ?in_search {id = tune.id; name = tune.name}

  let description (tune : Tune_view.t) =
    let kind = Kind.Base.to_long_string ~capitalised: false tune.kind in
    match tune.composers with
    | [] -> [txt @@ String.capitalize_ascii kind]
    | [composer] when composer.name = "Traditional" -> [txtf "Traditional %s" kind]
    | composers ->
      (txtf "%s by " @@ String.capitalize_ascii kind) :: Person.names_with_details composers
end

module Version = struct
  let id id =
    span [a ~a: [a_href @@ Endpoints.Page.href_version id] [txt @@ Id.to_string id]]

  let name ?(link = true) ?in_search ?in_set (version : Version_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_version ?in_search ?in_set version.id) (switch_signal_option in_search)]
        [txt version.name]
    else
      txt version.name

  let name_row ?(link = true) ?in_search ?in_set (version : Version_row.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_version ?in_search ?in_set version.id) (switch_signal_option in_search)]
        [txt version.tune.name]
    else
      txt version.tune.name

  let names ?link versions = several (name ?link) versions

  let name_disambiguation_and_sources ?links ?in_search ?in_set (version : Version_row.t) =
    let sources_block =
      match version.sources with
      | [] -> []
      | _ ->
        List.flatten [
          [txt " (from "];
          List.interspersei
            (fun _ -> txt ", ")
            ~last: (fun _ -> txt " and ")
            (List.map (Source.short_name ?link: links) version.sources);
          [txt ")"];
        ]
    in
    let disambiguation_block =
      Option.fold
        version.disambiguation
        ~none: []
        ~some: (fun disambiguation -> [txt " "; details [txtf "(%s)" disambiguation]])
    in
    [
      name_row ?link: links ?in_search ?in_set version;
      details sources_block;
      details disambiguation_block;
    ]

  let composer_and_arranger ?(short = false) ?links (version : Version_row.t) =
    Person.names ?links ~short version.tune.composers @
      match version.arrangers with
      | [] -> []
      | _ ->
        [
          details (
            (match version.tune.composers with [] -> [] | _ -> [txt ", "]) @
            [txt (if short then "arr. " else "arranged by ")] @
            Person.names ?links ~short version.arrangers
          )
        ]

  let parameters params =
    let params = Option.value params ~default: Version_parameters.none in
    let display_name_block =
      match Version_parameters.display_name params with
      | None -> []
      | Some display_name -> [txtf " [as “%s”]" @@ NEString.to_string display_name]
    in
    let structure_block =
      match Version_parameters.structure params with
      | None | Some Force_no_structure -> []
      | Some Structure structure -> [txtf " [play %s]" @@ NEString.to_string @@ Version_content.Structure.to_string structure]
    in
    let transposition_block =
      match Version_parameters.transposition params with
      | None -> []
      | Some transposition -> [txtf " [%+d m2]" @@ Music.Transposition.to_semitones transposition]
    in
    display_name_block @ structure_block @ transposition_block

  let display_composer params =
    let params = Option.value params ~default: Version_parameters.none in
    match Version_parameters.display_composer params with
    | None -> []
    | Some display_composer -> [txtf " [as “%s”]" @@ NEString.to_string display_composer]

  let names_disambiguations_sources_and_params ?links versions =
    several' (fun (version, params) -> name_disambiguation_and_sources ?links version @ parameters (Some params)) versions

  let composers_arrangers_and_params ?short ?links versions =
    several' (fun (version, params) -> composer_and_arranger ?short ?links version @ display_composer (Some params)) versions
end

module Set = struct
  let name ?(link = true) ?in_search (set : Set_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_set ?in_search set.id) (switch_signal_option in_search)]
        [txt set.name]
    else
      txt set.name

  let name_row ?(link = true) ?in_search (set : Set_row.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_set ?in_search set.id) (switch_signal_option in_search)]
        [txt set.name]
    else
      txt set.name

  let tunes ?links (set : Set_row.t) =
    set.tunes
    |> List.map (Version.name ?link: links)
    |> List.interspersei (fun _ -> txt " - ")
    |> List.cons (txt "Tunes: ")
end

module Book = struct
  let name ?(link = true) ?in_search (book : Book_name.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_book ?in_search book.id) (switch_signal_option in_search)]
        [txt book.name]
    else
      txt book.name

  let name_row ?(link = true) ?in_search (book : Book_row.t) =
    if link then
      a
        ~a: [R.a_href @@ S.map (fun in_search -> Endpoints.Page.href_book ?in_search book.id) (switch_signal_option in_search)]
        [txt book.name]
    else
      txt book.name

  let date_and_editors (book : Book_view.t) =
    let date =
      match book.date with
      | None -> []
      | Some date -> [txt (spf "Published %s" (Partial_date.to_pretty_string ~at: true date))]
    in
    let editors =
      match book.authors with
      | [] -> []
      | editors -> txt "by " :: Person.names ~links: true editors
    in
    date @ [txt " "] @ editors
end
