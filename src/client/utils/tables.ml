open Nes
open Dancelor_common
open Html

(** {2 Rows} *)

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

let inline_details = Formatters.details
let block_details content = p ~a: [a_class ["mb-0"; "opacity-50"; "lh-sm"]] [small content]

(* FIXME: add a tooltip explaining what a forbidden value is *)
let format_forbidden f = function
  | Allowed set -> f set
  | Forbidden -> span ~a: [a_class ["badge"; "text-bg-secondary"; "pe-none"]] [Icon.html (Other Forbidden); txt " Private"]

let part_row ?classes ?onclick ?(prefix = []) ?(suffix = []) title =
  row ?classes ?onclick (prefix @ [td ~a: [a_colspan 3] [txt title]] @ suffix)

let source_row ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (source : Source_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td [Formatters.Source.name_row ~link: (onclick = None) ?in_search source];
      td [txt @@ Option.fold ~none: "" ~some: (Partial_date.to_pretty_string ~short: true) source.date];
      td (Formatters.Person.names ~links: (onclick = None) ~short: true source.editors);
      ] @
      suffix
    )

let person_row ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (person : Person_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td ~a: [a_colspan 3] [Formatters.Person.name ~link: (onclick = None) ?in_search person];
      ] @
      suffix
    )

let dance_row ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (dance : Dance_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td (Formatters.Dance.name_and_disambiguation ~link: (onclick = None) ?in_search dance);
      td [txt @@ Kind.Dance.to_string dance.kind];
      td (Formatters.Person.names ~links: (onclick = None) ~short: true dance.devisers);
      ] @
      suffix
    )

let dance_plus_set_row ?classes ?onclick ?in_search ?set_params ?(prefix = []) ?(suffix = []) (dance : Dance_row.t) (set : Set_row.t or_forbidden) =
  row ?classes ?onclick (
    prefix @
    [td (
      [Formatters.Dance.name_row ?in_search dance] @
      [block_details [txt "Set: "; format_forbidden (Formatters.Set.name_row ~link: (onclick = None)) set]] @
      Option.fold
        (Option.bind set_params Set_parameters.display_name)
        ~none: []
        ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]]) @ (
        match set with
        | Forbidden -> []
        | Allowed set -> [block_details (Formatters.Set.tunes ~links: (onclick = None) set)]
      )
    );
    td [txt @@ Kind.Dance.to_string dance.kind];
    td (
      (
        match set with
        | Forbidden -> []
        | Allowed set -> Formatters.Person.names ~links: (onclick = None) ~short: true set.conceptors
      ) @
        Option.fold
          (Option.bind set_params Set_parameters.display_conceptor)
          ~none: []
          ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]])
    )] @
    suffix
  )

let dance_plus_versions_row ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (dance : Dance_row.t) versions_and_params =
  row ?classes ?onclick (
    prefix @
    [td [
      Formatters.Dance.name_row ?in_search dance;
      block_details [
        txt (if List.is_singleton versions_and_params then "Tune: " else "Tunes: ");
        Formatters.Version.names_disambiguations_sources_and_params versions_and_params
      ];
    ];
    td [txt @@ Kind.Dance.to_string dance.kind];
    td [Formatters.Version.composers_arrangers_and_params ~short: true versions_and_params]] @
    suffix
  )

let book_row ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (book : Book_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td [Formatters.Book.name_row ~link: (onclick = None) ?in_search book];
      td [txt @@ Option.fold ~none: "" ~some: (Partial_date.to_pretty_string ~short: true) book.date];
      td (Formatters.Person.names ~links: (onclick = None) ~short: true book.authors);
      ] @
      suffix
    )

let set_or_forbidden_row ?classes ?onclick ?in_search ?params ?(prefix = []) ?(suffix = []) (set : Set_row.t or_forbidden) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td (
        [format_forbidden (Formatters.Set.name_row ~link: (onclick = None) ?in_search) set] @
        Option.fold
          (Option.bind params Set_parameters.display_name)
          ~none: []
          ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]]) @ (
          match set with
          | Forbidden -> []
          | Allowed set -> [block_details (Formatters.Set.tunes ~links: (onclick = None) set)]
        )
      );
      td [txt (match set with Forbidden -> "" | Allowed set -> Kind.Dance.to_string set.kind)];
      td (
        (
          match set with
          | Forbidden -> []
          | Allowed set -> Formatters.Person.names ~links: (onclick = None) ~short: true set.conceptors
        ) @
          Option.fold
            (Option.bind params Set_parameters.display_conceptor)
            ~none: []
            ~some: (fun display_name -> [inline_details [txtf " [as “%s”]" @@ NEString.to_string display_name]])
      )] @
      suffix
    )

let set_row ?classes ?onclick ?in_search ?params ?prefix ?suffix (set : Set_row.t) =
  set_or_forbidden_row ?classes ?onclick ?in_search ?params ?prefix ?suffix (Allowed set)

let tune_row ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (tune : Tune_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td [Formatters.Tune.name_row ~link: (onclick = None) ?in_search tune];
      td [txt @@ Kind.Base.to_long_string ~capitalised: true tune.kind];
      td (Formatters.Person.names ~links: (onclick = None) ~short: true tune.composers);
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
      (NEString.to_string @@ Version_content.Structure.to_string structure)

let version_row ?classes ?onclick ?in_search ?(prefix = []) ?(suffix = []) (version : Version_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td (Formatters.Version.name_disambiguation_and_sources ~links: (onclick = None) ?in_search version);
      td [format_version_kind_and_structure version];
      td (Formatters.Version.composer_and_arranger ~links: (onclick = None) ~short: true version);
      ] @
      suffix
    )

let versions_row ?classes ?onclick ?(prefix = []) ?(suffix = []) versions_and_params =
  row ?classes ?onclick (
    prefix @
    [td [Formatters.Version.names_disambiguations_sources_and_params versions_and_params];
    td (
      let all_kinds = List.sort_uniq Kind.Base.compare (List.map (fun (version, _) -> version.Version_row.tune.kind) versions_and_params) in
      [
        txt @@
          match all_kinds with
          | [kind] -> Kind.Base.to_long_string ~capitalised: true kind ^ (if List.is_singleton versions_and_params then "" else "s")
          | _ -> "Medley"
      ]
    );
    td [Formatters.Version.composers_arrangers_and_params ~short: true versions_and_params]] @
    suffix
  )

let user_row ?classes ?onclick ?(prefix = []) ?(suffix = []) (user : User_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td ~a: [a_colspan 3] [Formatters.User.username ~link: (onclick = None) (User_row.to_name user)];
      ] @
      suffix
    )

let group_row ?classes ?onclick ?(prefix = []) ?(suffix = []) (group : Group_row.t) =
  row
    ?classes
    ?onclick
    (
      prefix @
      [td ~a: [a_colspan 3] [Formatters.Group.name ~link: (onclick = None) (Group_row.to_name group)];
      ] @
      suffix
    )

let entity_to_icon_and_string = function
  | `Source _ -> (Icon.Source, "Source")
  | `Person _ -> (Icon.Person, "Person")
  | `Dance _ -> (Icon.Dance, "Dance")
  | `Tune _ -> (Icon.Tune, "Tune")
  | `Version _ -> (Icon.Version, "Version")
  | `Set _ -> (Icon.Set, "Set")
  | `Book _ -> (Icon.Book, "Book")
  | `User _ -> (Icon.User, "User")
  | `Group _ -> (Icon.Group, "Group")

let entity_row ?classes ?onclick ?(prefix = []) ?(suffix = []) ?in_search (entity : [< Entity_row.t]) =
  let prefix =
    let (icon, type_) = entity_to_icon_and_string entity in
    prefix @ [
      td
        ~a: [a_class ["text-nowrap"; "pe-none"]]
        [
          Icon.(html (Entity icon));
          span ~a: [a_class ["d-none"; "d-sm-inline"]] [txt " "; txt type_];
        ]
    ]
  in
  let suffix =
    [td
      ~a: [a_class ["text-end"]]
      [
        let permission =
          match entity with
          | `Source _ -> None
          | `Person _ -> None
          | `Dance _ -> None
          | `Tune _ -> None
          | `Version _ -> None
          | `Set set -> Some set.Set_row.permission
          | `Book book -> Some book.Book_row.permission
          | `User _ -> None
          | `Group _ -> None
        in
        match permission with
        | None -> Icon.html Icon.(Access Everyone) ~tooltip: "You can see this entry because it is an always-public entry (eg. a person or a tune)" ~classes: ["opacity-25"]
        | Some permission ->
          let (icon, tooltip, classes) =
            match Permission.view_reason permission with
            | Public -> (Icon.(Access Everyone), "You can see this entry because it was made public by its owner.", ["opacity-50"])
            | Viewer -> (Icon.(Access Viewer), "You can see this entry because its owner marked you as one of its viewers.", ["opacity-75"])
            | Owner -> (Icon.(Access Owner), "You can see this entry because you are (one of) its owners.", [])
            | Omniscient_administrator -> (Icon.(Access Omniscient_administrator), "You can see this entry because you are an administrator, with omniscience enabled. You would not be able to access it without that.", [])
          in
          Icon.html icon ~tooltip ~classes
      ]] @
      suffix
  in
  match entity with
  | `Source source -> source_row ?classes ?onclick ?in_search ~prefix ~suffix source
  | `Person person -> person_row ?classes ?onclick ?in_search ~prefix ~suffix person
  | `Dance dance -> dance_row ?classes ?onclick ?in_search ~prefix ~suffix dance
  | `Book book -> book_row ?classes ?onclick ?in_search ~prefix ~suffix book
  | `Set set -> set_row ?classes ?onclick ?in_search ~prefix ~suffix set
  | `Tune tune -> tune_row ?classes ?onclick ?in_search ~prefix ~suffix tune
  | `Version version -> version_row ?classes ?onclick ?in_search ~prefix ~suffix version
  | `User user -> user_row ?classes ?onclick ~prefix ~suffix user
  | `Group group -> group_row ?classes ?onclick ~prefix ~suffix group

(** {2 Tables} *)

let make ?header body =
  div
    ~a: [a_class ["table-responsive"; "mx-n2"; "mx-sm-0"]]
    [
      tablex
        ~a: [a_class ["table"; "table-striped"; "table-hover"; "table-borderless"; "my-1"]]
        ?thead: (Option.map (fun header -> thead ~a: [a_class ["table-primary"; "pe-none"]] [tr (List.map (fun str -> th [txt str]) header)]) header)
        ?tfoot: (Option.map (fun header -> tfoot ~a: [a_class ["table-primary"; "pe-none"]] [tr (List.map (fun str -> th [txt str]) header)]) header)
        [body]
    ]

let map_table ?header f list =
  make ?header (tbody (List.map f list))

let dances dances =
  map_table ~header: [""; ""; ""] dance_row dances

let tunes tunes =
  map_table ~header: [""; ""; ""] tune_row tunes

let users users =
  map_table ~header: [""; ""; ""] user_row users

let versions ?onclick versions =
  map_table
    ~header: [""; ""; ""]
    (fun version ->
      version_row
        ?onclick: (Option.map (fun onclick () -> onclick version) onclick)
        version
    )
    versions

let entities ?in_search entities =
  map_table ~header: [""; ""; ""; ""; ""] (entity_row ?in_search) entities

let placeholder ?(show_thead = true) ?(show_tfoot = true) ?(rows = 3) () = [
  div
    ~a: [a_class ["table-responsive"]]
    [
      tablex
        ~a: [a_class ["table"; "table-striped"; "table-hover"; "table-borderless"; "my-1"]]
        ?thead: (
          if show_thead then
            some @@
              thead
                ~a: [a_class ["table-primary"]]
                [
                  tr [
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                  ];
                ]
          else None
        )
        ?tfoot: (
          if show_tfoot then
            some @@
              tfoot
                ~a: [a_class ["table-primary"]]
                [
                  tr [
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                  ];
                ]
          else None
        )
        [
          tbody (
            List.init rows (fun _ ->
              tr [
                td [span_placeholder ()];
                td [span_placeholder ()];
                td [span_placeholder ()];
              ];
            )
          )
        ]
    ]
]
