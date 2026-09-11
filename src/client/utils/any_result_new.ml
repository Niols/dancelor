open Nes
open Dancelor_common
open Model_new
open Html

let row ?(classes = []) ?onclick cells =
  let open Html in
  tr
    ~a: (
      List.filter_map id [
        Some (a_class classes);
        Option.map (fun _ -> a_style "cursor: pointer;") onclick;
        Option.map (fun f -> a_onclick (fun _ -> Lwt.async f; true)) onclick;
      ]
    )
    (cells)

let inline_details = Formatters_new.details
let block_details content = p ~a: [a_class ["mb-0"; "opacity-50"; "lh-sm"]] [small content]

(* FIXME: add a tooltip explaining what a forbidden value is *)
let format_forbidden f = function
  | Allowed set -> f set
  | Forbidden -> span ~a: [a_class ["badge"; "text-bg-secondary"; "pe-none"]] [Icon.html (Other Forbidden); txt " Private"]

let make_part_result ?classes ?onclick ?(prefix = []) ?(suffix = []) title =
  row ?classes ?onclick (prefix @ [td ~a: [a_colspan 3] [txt title]] @ suffix)

let make_source_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (source : Source_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td [Formatters_new.Source.name_row ~link: (onclick = None) ?in_search source];
      td [txt @@ Option.fold ~none: "" ~some: (PartialDate.to_pretty_string ~short: true) source.date];
      td (Formatters_new.Person.names ~links: (onclick = None) ~short: true source.editors);
      ] @
      suffix
    )

let make_person_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (person : Person_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td ~a: [a_colspan 3] [Formatters_new.Person.name ~link: (onclick = None) ?in_search person];
      ] @
      suffix
    )

let make_user_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (user : User_row.t) =
  ignore in_search;
  (* FIXME *)
  row
    ?classes
    ?onclick
    (
      prefix @
      [td ~a: [a_colspan 3] [txt @@ Username.to_string user.username];
      ] @
      suffix
    )

let make_dance_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (dance : Dance_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td (Formatters_new.Dance.name_and_disambiguation ~link: (onclick = None) ?in_search dance);
      td [txt @@ Kind.Dance.to_string dance.kind];
      td (Formatters_new.Person.names ~links: (onclick = None) ~short: true dance.devisers);
      ] @
      suffix
    )

let make_dance_plus_set_result ?classes ?onclick ?in_search ?set_params ?(prefix = []) ?(suffix = []) (dance : Dance_row.t) (set : Set_row.t or_forbidden) =
  row ?classes ?onclick (
    prefix @
    [td (
      [Formatters_new.Dance.name_row ?in_search dance] @
      [block_details [txt "Set: "; format_forbidden (Formatters_new.Set.name_row ~link: (onclick = None)) set]] @
      Option.fold
        (Option.bind set_params Model_builder.Core.Set_parameters.display_name)
        ~none: []
        ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]]) @ (
        match set with
        | Forbidden -> []
        | Allowed set -> [block_details (Formatters_new.Set.tunes ~links: (onclick = None) set)]
      )
    );
    td [txt @@ Kind.Dance.to_string dance.kind];
    td (
      (
        match set with
        | Forbidden -> []
        | Allowed set -> Formatters_new.Person.names ~links: (onclick = None) ~short: true set.conceptors
      ) @
        Option.fold
          (Option.bind set_params Model_builder.Core.Set_parameters.display_conceptor)
          ~none: []
          ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]])
    )] @
    suffix
  )

let make_dance_plus_versions_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (dance : Dance_row.t) versions_and_params =
  row ?classes ?onclick (
    prefix @
    [td [
      Formatters_new.Dance.name_row ?in_search dance;
      block_details [
        txt (if List.is_singleton versions_and_params then "Tune: " else "Tunes: ");
        Formatters_new.Version.names_disambiguations_sources_and_params versions_and_params
      ];
    ];
    td [txt @@ Kind.Dance.to_string dance.kind];
    td [Formatters_new.Version.composers_arrangers_and_params ~short: true versions_and_params]] @
    suffix
  )

let make_book_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (book : Book_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td [Formatters_new.Book.name ~link: (onclick = None) ?in_search book];
      td [txt @@ Option.fold ~none: "" ~some: (PartialDate.to_pretty_string ~short: true) book.date];
      td (Formatters_new.Person.names ~links: (onclick = None) ~short: true book.authors);
      ] @
      suffix
    )

let make_set_or_forbidden_result ?classes ?onclick ?in_search ?params ?(prefix = []) ?(suffix = []) (set : Set_row.t or_forbidden) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td (
        [format_forbidden (Formatters_new.Set.name_row ~link: (onclick = None) ?in_search) set] @
        Option.fold
          (Option.bind params Model_builder.Core.Set_parameters.display_name)
          ~none: []
          ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]]) @ (
          match set with
          | Forbidden -> []
          | Allowed set -> [block_details (Formatters_new.Set.tunes ~links: (onclick = None) set)]
        )
      );
      td [txt (match set with Forbidden -> "" | Allowed set -> Kind.Dance.to_string set.kind)];
      td (
        (
          match set with
          | Forbidden -> []
          | Allowed set -> Formatters_new.Person.names ~links: (onclick = None) ~short: true set.conceptors
        ) @
          Option.fold
            (Option.bind params Model_builder.Core.Set_parameters.display_conceptor)
            ~none: []
            ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]])
      )] @
      suffix
    )

let make_set_result ?classes ?onclick ?in_search ?params ?prefix ?suffix (set : Set_row.t) =
  make_set_or_forbidden_result ?classes ?onclick ?in_search ?params ?prefix ?suffix (Allowed set)

let make_tune_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (tune : Tune_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td [Formatters_new.Tune.name_row ~link: (onclick = None) ?in_search tune];
      td [txt @@ Kind.Base.to_long_string ~capitalised: true tune.kind];
      td (Formatters_new.Person.names ~links: (onclick = None) ~short: true tune.composers);
      ] @
      suffix
    )

let format_version_kind_and_structure (version : Version_row.t) =
  match version.content with
  | No_content ->
    txt "(no cont.)"
  | Destructured ->
    txt @@ "∗ " ^ Kind.Base.to_short_string version.tune.kind ^ " (destr.)"
  | Monolithic {bars; structure} ->
    txtf
      "%s (%s)"
      (Kind.Version.to_string (bars, version.tune.kind))
      (NEString.to_string @@ Model.Version.Structure.to_string structure)

let make_version_result ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (version : Version_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td (Formatters_new.Version.name_disambiguation_and_sources ~links: (onclick = None) ?in_search version);
      td [format_version_kind_and_structure version];
      td (Formatters_new.Version.composer_and_arranger ~links: (onclick = None) ~short: true version);
      ] @
      suffix
    )

let make_versions_result ?classes ?onclick ?(prefix = []) ?(suffix = []) versions_and_params =
  row ?classes ?onclick (
    prefix @
    [td [Formatters_new.Version.names_disambiguations_sources_and_params versions_and_params];
    td (
      let all_kinds = List.sort_uniq Kind.Base.compare (List.map (fun (version, _) -> version.Version_row.tune.kind) versions_and_params) in
      [
        txt @@
          match all_kinds with
          | [kind] -> Kind.Base.to_long_string ~capitalised: true kind ^ (if List.is_singleton versions_and_params then "" else "s")
          | _ -> "Medley"
      ]
    );
    td [Formatters_new.Version.composers_arrangers_and_params ~short: true versions_and_params]] @
    suffix
  )

let any_to_icon_and_string any =
  match (any : Any_row.t) with
  | Source _ -> (Icon.Source, "Source")
  | Person _ -> (Icon.Person, "Person")
  | Dance _ -> (Icon.Dance, "Dance")
  | Tune _ -> (Icon.Tune, "Tune")
  | Version _ -> (Icon.Version, "Version")
  | Set _ -> (Icon.Set, "Set")
  | Book _ -> (Icon.Book, "Book")
  | User _ -> (Icon.User, "User")

let make_result ?classes ?in_search (any : Any_row.t) =
  let prefix =
    let (icon, type_) = any_to_icon_and_string any in
    [
      td
        ~a: [a_class ["text-nowrap"; "pe-none"]]
        [
          Icon.(html (Model icon));
          span ~a: [a_class ["d-none"; "d-sm-inline"]] [txt " "; txt type_];
        ]
    ]
  in
  let suffix = [
    td
      ~a: [a_class ["text-end"]]
      [
        let permission =
          match any with
          | Source _ -> None
          | Person _ -> None
          | Dance _ -> None
          | Tune _ -> None
          | Version _ -> None
          | Set set -> Some set.permission
          | Book book -> Some book.permission
          | User _ -> None
        in
        match permission with
        | None -> Icon.html Icon.(Access Everyone) ~tooltip: "You can see this entry because it is an always-public entry (eg. a person or a tune)" ~classes: ["opacity-25"]
        | Some permission ->
          let (icon, tooltip, classes) =
            match Permission_new.view_reason permission with
            | Public -> (Icon.(Access Everyone), "You can see this entry because it was made public by its owner.", ["opacity-50"])
            | Viewer -> (Icon.(Access Viewer), "You can see this entry because its owner marked you as one of its viewers.", ["opacity-75"])
            | Owner -> (Icon.(Access Owner), "You can see this entry because you are (one of) its owners.", [])
            | Omniscient_administrator -> (Icon.(Access Omniscient_administrator), "You can see this entry because you are an administrator, with omniscience enabled. You would not be able to access it without that.", [])
          in
          Icon.html icon ~tooltip ~classes
      ]
  ]
  in
  match any with
  | Source source -> make_source_result ?classes ?in_search ~prefix ~suffix source
  | Person person -> make_person_result ?classes ?in_search ~prefix ~suffix person
  | Dance dance -> make_dance_result ?classes ?in_search ~prefix ~suffix dance
  | Book book -> make_book_result ?classes ?in_search ~prefix ~suffix book
  | Set set -> make_set_result ?classes ?in_search ~prefix ~suffix set
  | Tune tune -> make_tune_result ?classes ?in_search ~prefix ~suffix tune
  | Version version -> make_version_result ?classes ?in_search ~prefix ~suffix version
  | User user -> make_user_result ?classes ?in_search ~prefix ~suffix user
