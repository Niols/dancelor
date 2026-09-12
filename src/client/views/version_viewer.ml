open Nes
open Dancelor_common
open Model
open Model_new
open Search_new
open Html
open Utils

let show_lilypond_dialog (version : Version_view.t) =
  let content_promise =
    let%lwt content = Madge_client.call_exn Endpoints.Api.(route @@ Version Content) version.id in
    let content =
      match content with
      | Endpoints.Version.Protected -> assert false
      | Endpoints.Version.Granted {payload; _} -> payload
    in
    lwt @@ Model.Version.Content.lilypond ~kind: version.tune.kind ~key: version.key content
  in
  ignore
  <$> Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "LilyPond")
      [with_div_placeholder (
        let%lwt content = content_promise in
        lwt [pre [txt (Option.get content)]]
      )]
      ~buttons: [
        Button.close' ~return ();
        Button.make
          ~label: "Copy to clipboard"
          ~icon: (Other Clipboard)
          ~classes: ["btn-primary"]
          ~onclick: (fun _ ->
            let%lwt content = content_promise in
            write_to_clipboard (Option.get content);
            Toast.open_ ~title: "Copied to clipboard" [txt "The LilyPond content was copied to your clipboard."];
            return (some ());
            lwt_unit
          )
          ()
      ]

let add_to_set_dialog (version : Version_name.t) =
  Add_to.dialog
    version
    ~source_type: "version"
    ~source_format: (txt % Version_name.name)
    ~target_type: "set"
    ~target_icon: Icon.(Model Set)
    ~target_format: Formatters.Set.name'
    ~target_href: Endpoints.Page.href_set
    ~target_result: (Any_result.make_set_result ?classes: None ?prefix: None ?suffix: None ?params: None)
    ~target_search: (fun slice query ->
      match Set_query.parse query with
      | Error msg -> lwt_error msg
      | Ok query ->
        let%lwt sets = Madge_client.call_exn Endpoints.Api.(route @@ Set Search) slice query in
        let%lwt items = Lwt_list.map_p (fun set -> Option.get <$> Model.Set.get set.Set_row.id) sets.items in
        lwt_ok {sets with items}
    )
    ~target_update: (Madge_client.call_exn Endpoints.Api.(route @@ Set Update))
    ~target_history: (fun () ->
      let%lwt sets = History.get_sets () in
      Lwt_list.map_p (fun set -> Option.get <$> Model.Set.get set.Set_row.id) sets
    )
    ~target_add_source_to_content: (fun set ->
      let contents = Model.Set.contents set in
      Model.Set.set_contents (contents @ [(version.id, Model.Version_parameters.none)]) set
    )

let madge_call_tune_or_version tune_or_version_id f =
  match tune_or_version_id with
  | `Tune id ->
    Main_page.madge_call_or_404 (Version Get_view_for_tune) id (function
      | Found version -> f version.tune (Some version)
      | Fallback tune -> f tune None
    )
  | `Version id ->
    Main_page.madge_call_or_404 (Version Get_view) id (fun version -> f version.tune (Some version))

let subtitles (tune : Tune_view.t) =
  [span (Formatters_new.Tune.description tune)]

let actions (tune : Tune_view.t) (version : Version_view.t option) = [
  (
    lwt @@
    Option.to_list @@
    Option.bind version @@ fun version ->
    match version.content with
    | No_content -> None
    | _ ->
      some @@
        Button.make
          ~label: "Download PDF"
          ~icon: (Other File_pdf)
          ~dropdown: true
          ~onclick: (fun _ -> ignore <$> Version_download_dialog.create_and_open (Version_view.to_name version))
          ()
  );
  (
    lwt @@
    Option.to_list @@
    Option.bind version @@ fun version ->
    match version.content with
    | No_content -> None
    | _ ->
      some @@
        Button.make
          ~label: "Show LilyPond"
          ~label_processing: "Showing LilyPond..."
          ~icon: (Other File_lilypond)
          ~dropdown: true
          ~onclick: (fun () -> show_lilypond_dialog version)
          ()
  );
  (
    match version with
    | None -> lwt_nil
    | Some version ->
      Lwt.l2
        (@)
        (Add_to.button ~target_type: "set" (fun _user -> add_to_set_dialog @@ Version_view.to_name version))
        (
          Add_to.button_to_book
            ~source_type: "version"
            ~source_format: (txt % Version_name.name)
            (Version_view.to_name version)
            (Model.Book.versions @@ NEList.singleton (version.id, Model.Version_parameters.none))
        )
  );
  (
    Option.fold
      version
      ~none: lwt_nil
      ~some: (fun version ->
        match%lwt Permission.can_update_public_new version with
        | None -> lwt_nil
        | Some _ ->
          lwt [
            Button.make_a
              ~label: "Edit version"
              ~icon: (Action Edit)
              ~href: (S.const @@ Endpoints.Page.(href @@ Version Edit) version.Version_view.id)
              ~dropdown: true
              ()
          ]
      )
  );
  (
    match%lwt Permission.can_update_public_new tune with
    | None -> lwt_nil
    | Some _ ->
      lwt [
        Button.make_a
          ~label: "Edit tune"
          ~icon: (Action Edit)
          ~href: (S.const @@ Endpoints.Page.(href @@ Tune Edit) tune.id)
          ~dropdown: true
          ()
      ]
  );
  (
    Option.fold
      version
      ~none: lwt_nil
      ~some: (fun version ->
        match%lwt Permission.can_delete_public_new version with
        | None -> lwt_nil
        | Some _ ->
          lwt [
            Action.delete
              ~label_suffix: "version"
              ~model: "version"
              ~onclick: (fun () -> Madge_client.call Endpoints.Api.(route @@ Version Delete) version.Version_view.id)
              ()
          ]
      )
  );
  (
    match%lwt Permission.can_delete_public_new tune with
    | None -> lwt_nil
    | Some _ ->
      lwt [
        Action.delete
          ~label_suffix: "tune"
          ~model: "tune"
          ~onclick: (fun () -> Madge_client.call Endpoints.Api.(route @@ Tune Delete) tune.id)
          ()
      ]
  );
  (
    Option.fold
      version
      ~none: lwt_nil
      ~some: (fun version ->
        match%lwt Permission.can_administrate () with
        | false -> lwt_nil
        | true ->
          let other_versions = List.filter (fun (v : Tune_view.version_row_without_tune) -> not @@ Entry.Id.equal' v.id version.Version_view.id) tune.versions in
          let other_versions = List.map (Tune_view.version_row_without_tune_to_version_row tune) other_versions in
          lwt [
            Button.make
              ~label: "De-duplicate"
              ~icon: (Action Deduplicate)
              ~dropdown: true
              ~classes: ["btn-warning"]
              ~onclick: (fun () -> Version_deduplicator.dialog version other_versions)
              ()
          ]
      )
  );
  (lwt @@ Option.to_list @@ Option.map (Action.scddb Tune) tune.scddb_id);
]

let body tune_or_version_id (tune : Tune_view.t) (version : Version_view.t option) = [
  div
    (
      match tune.date with
      | None -> []
      | Some date -> [txtf "Composed %s." (PartialDate.to_pretty_string ~at: true date)]
    );
  (
    div @@
    Option.value ~default: [] @@
    Option.flip_map version @@ fun version ->
    [div ~a: [a_class ["row"; "justify-content-between"]] [
      div ~a: [a_class ["col-auto"; "text-start"]] (
        match version.content with
        | No_content -> []
        | Monolithic {bars; structure} ->
          [
            txtf
              "Monolithic %d-bar %s version in %s"
              bars
              (NEString.to_string @@ Model.Version.Structure.to_string structure)
              (Music.Key.to_pretty_string version.key);
          ]
        | Destructured {default_structure} ->
          [
            txt "Destructured version ";
            Documentation.link "destructured-versions";
            txtf
              " in %s, shown here as %s"
              (Music.Key.to_pretty_string version.key)
              (NEString.to_string @@ Version.Structure.to_string default_structure);
          ]
      );
      div ~a: [a_class ["col-auto"; "text-end"]] (
        Option.fold version.disambiguation ~none: [] ~some: (List.singleton % txtf " %s") @
          match version.arrangers with
          | [] -> []
          | arrangers -> txt " arranged by " :: Formatters_new.Person.names ~links: true arrangers
      );
    ];
    (
      match version.content with
      | No_content -> div [Alert.make ~level: Info [txt "This version does not have any content. This is usually because it has not been added yet. If you have access to the source of this precise version, consider sending it to an administrator."]]
      | Monolithic _ | Destructured _ -> Components.Version_snippets.make (Version_view.to_name version)
    );
    (
      match tune_or_version_id with
      | `Version _ -> div []
      | `Tune _ -> div ~a: [a_class ["my-3"]] [Alert.make ~level: Info [txtf "This is the page of the tune “%s”; this specific version was selected by Dancelor." tune.name]]
    );
    ];
  );
  div (
    match tune.extra_names with
    | [] -> []
    | extra_names ->
      [
        section ~a: [a_class ["mt-2"]] [
          txt "Also known as:";
          ul (List.map (li % List.singleton % txt) extra_names);
        ];
      ]
  );
  div (
    Option.fold
      version
      ~none: []
      ~some: (fun version ->
        let show_source_group (source_group : Version_view.source list) =
          span @@
            let source = List.hd source_group in
            [Formatters_new.Source.name @@ Version_view.source_to_name source] @
            (
              List.concat @@
              List.interspersei
                (fun _ -> [txt ", "])
                ~last: (fun _ -> [txt " and "]) @@
              List.map
                (fun ({details; structure; _}: Version_view.source) ->
                  [
                    Option.fold details ~none: (txt "") ~some: (txtf " %s");
                    txtf " as %s" (NEString.to_string (Model.Version.Structure.to_string structure));
                  ]
                )
                source_group
            ) @
              [txt "."]
        in
        match List.group ~by: (fun (s1 : Version_view.source) (s2 : Version_view.source) -> Entry.Id.equal' s1.id s2.id) version.Version_view.sources with
        | [] -> []
        | source_groups ->
          [
            section ~a: [a_class ["mt-2"]] [
              txt "This specific version appears:";
              ul (
                List.map
                  (fun source_group -> li [txt "in "; show_source_group source_group])
                  source_groups
              );
            ];
          ]
      )
  );
  quick_explorer_links @@
    List.filter_map Fun.id [
      Option.flip_map version (fun version -> ("sets containing this version", Any_query.specific_only (Any_query.Set (Set_query.make_specific ~contains_version: (Some [version.id]) ()))));
      Some ("sets containing this tune", Any_query.specific_only (Any_query.Set (Set_query.make_specific ~contains_tune: (Some [tune.id]) ())));
      Option.flip_map version (fun version -> ("books containing this version", Any_query.specific_only (Any_query.Book (Book_query.make_specific ~contains_version: (Some [version.id]) ()))));
      Some ("books containing this tune", Any_query.specific_only (Any_query.Book (Book_query.make_specific ~contains_tune: (Some [tune.id]) ())));
    ];
  div (
    let (title, versions) =
      match version with
      | None -> ("Versions", tune.versions)
      | Some version -> ("Other versions", List.filter (fun (v : Tune_view.version_row_without_tune) -> not @@ Entry.Id.equal' v.id version.Version_view.id) tune.versions)
    in
    let versions = List.map (Tune_view.version_row_without_tune_to_version_row tune) versions in
    [
      h3 ~a: [a_class ["mt-3"]] [txtf "%s of this tune" title];
      (
        match versions with
        | [] ->
          Alert.make ~level: Info [
            txtf "There are no %sversions for this tune. " (if Option.is_some version then "other " else "");
            R.span (
              S.from_lwt [] @@
                if%lwt Environment.is_connected then
                  lwt [
                    txt "Do you maybe want to ";
                    a ~a: [a_href @@ Endpoints.Page.(href (Version Add) (Some tune.id))] [txt "add one"];
                    txt "?";
                  ]
                else lwt [txt "Did you maybe forget to sign in?"]
            )
          ]
        | _ ->
          Tables.versions versions
      );
    ]
  );
  div [
    h3 ~a: [a_class ["mt-3"]] [txt "Dances that recommend this tune"];
    (
      let dances = tune.dances in
      if dances = [] then
        txt "There are no dances that recommend this tune."
      else
        Tables.dances dances
    )
  ];
]

let view in_search in_set tune_or_version_id =
  madge_call_tune_or_version tune_or_version_id @@ fun tune version ->
  let (any_id, this_page) =
    match tune_or_version_id with
    | `Tune _ -> (Any_id.Tune tune.id, Endpoints.Page.href_tune tune.id)
    | `Version id -> (Any_id.Version id, Endpoints.Page.href_version id)
  in
  Page.make'
    ~parent_title: "Tune"
    ~before_title: [
      Components.Context_links.for_search in_search any_id;
      Components.Context_links.for_set ~this_page in_set;
    ]
    ~title: (lwt tune.name)
    ~subtitles: (subtitles tune)
    ~share: (
      Sharing_dialog.copy_link_button @@
        Option.fold version ~none: (Any_id.tune tune.id) ~some: (fun version -> Any_id.Version version.Version_view.id)
    )
    ~actions: (actions tune version)
    (body tune_or_version_id tune version)

let view_version in_search in_set id = view in_search in_set (`Version id)
let view_tune in_search id = view in_search None (`Tune id)
