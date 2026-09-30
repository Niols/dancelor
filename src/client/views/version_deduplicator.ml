open Nes
open Dancelor_common
open Model
open Model_new
open Search_new
open Html
open Utils

(* helpers to record all the changes that will be performed and spit them back
   to the user afterwards *)
let make_change_trackers () =
  let changes = ref [] in
  (
    (fun () -> List.rev_map fst !changes),
    (fun () -> List.rev_map snd !changes),
    (fun ?(action = fun () -> lwt_unit) html ->
      changes := (action, html) :: !changes
    )
  )

let version_model_to_version_row : Model.Version.entry -> Version_row.t Lwt.t = fun version ->
  let {Model_builder.Core.Version.tune; sources; arrangers; disambiguation; content; _} = Entry.value version in
  let%lwt tune = Api.call_exn (Tune Get_row) tune in
  let%lwt sources =
    Lwt_list.map_p
      (fun {Model_builder.Core.Version.source; _} ->
        Source_view.to_short_name <$> Api.call_exn (Source Get_view) source
      )
      sources
  in
  let%lwt arrangers =
    Lwt_list.map_p
      (fun arranger ->
        Person_row.to_name <$> Api.call_exn (Person Get_row) arranger
      )
      arrangers
  in
  let content : Version_row.content =
    match content with
    | No_content -> No_content
    | Destructured _ -> Destructured
    | Monolithic {bars; structure; _} -> Monolithic {bars; structure}
  in
  lwt {
    Version_row.id =
    Entry.id version;
    tune;
    sources;
    disambiguation = Option.map NEString.to_string disambiguation;
    arrangers;
    content;
  }

(* /!\ deduplicate this version INTO the other version *)
let confirmation_dialog ~this_version ~other_version =
  let%lwt this_version_row : Version_row.t = version_model_to_version_row this_version in
  let%lwt other_version_row : Version_row.t = version_model_to_version_row other_version in
  let (get_changes_actions, get_changes_html, add_changes) = make_change_trackers () in

  (* changes to other version *)
  let%lwt () =
    let (_, get_other_version_changes, add_other_version_changes) =
      make_change_trackers ()
    in
    (* tune *)
    let%lwt this_tune = Model.Version.tune' this_version in
    let%lwt other_tune = Model.Version.tune' other_version in
    if not (Entry.equal' this_tune other_tune) then
      failwith "Version de-duplicator: these two versions do not share the same tune.";
    (* key *)
    let this_key = Model.Version.key' this_version in
    let other_key = Model.Version.key' other_version in
    if this_key <> other_key then
      failwith "Version de-duplicator: these two versions do not share the same key.";
    (* FIXME: can do better? *)
    (* sources *)
    let this_sources = Model.Version.sources' this_version in
    let other_sources = Model.Version.sources' other_version in
    let other_sources = other_sources @ this_sources in
    (* FIXME: de-duplicate and detect the changes? *)
    (
      match this_sources with
      | [] -> ()
      | _ ->
        add_other_version_changes [
          txt "add the following sources:";
          R.ul (
            S.from_lwt [] @@
              Lwt_list.map_p
                (fun Model.Version.{source; structure; _} ->
                  let%lwt source = Option.get <$> Model.Source.get source in
                  lwt @@
                    li [
                      Formatters.Source.name' source;
                      txtf " (%s)" (NEString.to_string @@ Version.Structure.to_string structure);
                    ]
                )
                this_sources
          );
        ]
    );
    (* arrangers *)
    let%lwt this_arrangers = Lwt_list.map_p (Option.get <%> Model.Person.get) (Model.Version.arrangers' this_version) in
    let%lwt other_arrangers = Lwt_list.map_p (Option.get <%> Model.Person.get) (Model.Version.arrangers' other_version) in
    if this_arrangers <> other_arrangers then
      failwith "Version de-duplicator: these two versions do not share the same arrangers.";
    (* FIXME: can do better? *)
    (* remark *)
    let this_remark = Model.Version.remark' this_version in
    let other_remark = Model.Version.remark' other_version in
    if this_remark <> other_remark then
      failwith "Version de-duplicator: these two versions do not share the same remark.";
    (* FIXME: can do better? *)
    (* disambiguation *)
    let this_disambiguation = Model.Version.disambiguation' this_version in
    let other_disambiguation = Model.Version.disambiguation' other_version in
    if this_disambiguation <> other_disambiguation then
      failwith "Version de-duplicator: these two versions do not share the same disambiguation.";
    (* FIXME: can do better? *)
    (* content *)
    let%lwt other_content = Api.call_exn (Version Content) (Entry.id other_version) in
    let other_content =
      match other_content with
      | Endpoints.Version.Protected -> assert false
      | Endpoints.Version.Granted {payload; _} -> payload
    in
    add_other_version_changes [txt "use its content; the content of the current version will be lost entirely."];
    (* that's it for changes to the other version; bundle them together as a change *)
    let other_version_formatted =
      span [
        Formatters.Version.name_disambiguation_and_sources' other_version;
        txt " [";
        Formatters.Version.id' other_version;
        txt "]"
      ]
    in
    (
      match get_other_version_changes () with
      | [] ->
        add_changes [txt "This will not change anything to the other version, "; other_version_formatted; txt "."];
      | changes ->
        add_changes
          ~action: (fun () ->
            (* FIXME: we should clearly not be reconstructing anything here but
               have the right data right away *)
            let%lwt other_composers =
              Lwt_list.map_p
                (fun {Tune.composer; _} ->
                  Api.call_exn (Person Get_row) composer
                )
                (Model.Tune.composers' other_tune)
            in
            let%lwt other_sources =
              Lwt_list.map_p
                (fun {Version.source; structure; details} ->
                  let%lwt source = Api.call_exn (Source Get_row) source in
                  lwt {Version_form.source; structure; details}
                )
                other_sources
            in
            let other_arrangers =
              List.map
                (fun arranger ->
                  {
                    Person_row.id = Entry.id arranger;
                    name = NEString.to_string @@ Model.Person.name' arranger;
                  }
                )
                other_arrangers
            in
            ignore
            <$> Api.call_exn
                (Version Update)
                (Entry.id other_version)
                {
                  Version_form.tune = {
                    Tune_row.id = Entry.id other_tune;
                    name = NEString.to_string @@ NEList.hd @@ Model.Tune.names' other_tune;
                    kind = Model.Tune.kind' other_tune;
                    composers = other_composers;
                  };
                  key = other_key;
                  sources = other_sources;
                  arrangers = other_arrangers;
                  remark = other_remark;
                  disambiguation = other_disambiguation;
                  content = other_content;
                }
          (* FIXME: we should report nicely if things fail *)
          )
          [
            txt "update the other version, ";
            other_version_formatted;
            txt ", in the following way:";
            ul (List.map li changes);
          ]
    );
    lwt_unit
  in

  (* how to update a version from a set or a book *)
  let replace_version a_version =
    if Entry.Id.equal' a_version (Entry.id this_version) then
      Entry.id other_version
    else
      a_version
  in

  (* how to update a version from a set or a book *)
  let replace_version_new (a_version : Version_row.t) =
    if Entry.Id.equal' a_version.id this_version_row.id then
      other_version_row
    else
      a_version
  in

  (* changes to sets *)
  let%lwt sets =
    Search_result.items
    <$> Api.call_exn (Set Search) Slice.everything @@
        Query.make ~specific: (Set_query.make_specific ~contains_version: (Some [Entry.id this_version]) ()) ()
  in
  let%lwt sets =
    Lwt_list.map_p
      (fun {Set_row.id; _} ->
        Pair.cons id <$> Api.call_exn (Set Get_form) id
      )
      sets
  in
  List.iter
    (fun (id, set) ->
      add_changes
        ~action: (fun () ->
          let contents = List.map (Pair.map_fst replace_version_new) set.Set_form.contents in
          ignore <$> Api.call_exn (Set Update) id {set with contents}
        )
        [txt "replace the version in set "; Formatters_new.Set.name (Set_form.to_name id set); txt "."]
    )
    sets;

  (* changes to books *)
  let%lwt books =
    Search_result.items
    <$> Api.call_exn (Book Search) Slice.everything @@
        Query.make ~specific: (Book_query.make_specific ~contains_version: (Some [Entry.id this_version]) ()) ()
  in
  let%lwt books = Lwt_list.map_p (fun book -> Option.get <$> Model.Book.get book.Book_row.id) books in
  List.iter
    (fun book ->
      add_changes
        ~action: (fun () ->
          let contents =
            List.map
              (function
                | Model.Book.Dance (dance, Dance_versions versions_and_params) ->
                  Model.Book.Dance (dance, Model.Book.Dance_versions (NEList.map (Pair.map_fst replace_version) versions_and_params))
                | Model.Book.Versions versions_and_params ->
                  Model.Book.Versions (NEList.map (Pair.map_fst replace_version) versions_and_params)
                | page -> page
              )
              (Model.Book.contents' book)
          in
          ignore
          <$> Api.call_exn
              (Book Update)
              (Entry.id book)
              (Model.Book.set_contents contents (Entry.value book))
              (Entry.access book)
        )
        [
          txt "replace the version in book ";
          Formatters.Book.name' book;
          txt "."
        ]
    )
    books;

  (* removal of the current version *)
  add_changes
    ~action: (fun () -> ignore <$> Api.call_exn (Version Delete) (Entry.id this_version))
    [
      txt "delete the current version, ";
      Formatters.Version.name_disambiguation_and_sources' this_version;
      txt " [";
      Formatters.Version.id' this_version;
      txt "].";
    ];

  (* report *)
  let%lwt user_input =
    Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "De-duplicate a version")
      [Alert.make ~level: Warning [txt "This action is irreversible."];
      div ~a: [a_class ["mt-4"]] [txt "This will:"; ul (List.map li (get_changes_html ()))]]
      ~buttons: [
        Button.cancel' ~return ();
        Button.make
          ~classes: ["btn-primary"]
          ~label: "Proceed"
          ~label_processing: "Proceeding"
          ~icon: (Action Deduplicate)
          ~onclick: (lwt % return % some)
          ();
      ]
  in
  (* let's go *)
  match user_input with
  | None -> lwt_unit
  | Some() ->
    Toast.open_
      ~title: "De-duplicating a version"
      [
        txt
          "Dancelor has started de-duplicating this version. Hopefully, you see \
           no error, and another toast comes to announce the good news! \
           Otherwise, please report immediately to a system administrator, \
           because the database might be in an odd state.";
      ];
    Lwt_list.iter_s (fun action -> action ()) (get_changes_actions ());%lwt
    Toast.open_
      ~type_: Forever
      ~title: "De-duplicated a version"
      [txt
        "The version has been de-duplicated successfully! This means that \
           you are on a page that does not exist anymore. Run, you fools!"]
      ~buttons: [
        Button.make_a
          ~label: "Go to other version"
          ~icon: (Model Version)
          ~classes: ["btn-primary"]
          ~href: (S.const @@ Endpoints.Page.href_version (Entry.id other_version))
          ();
      ];
    lwt_unit

let dialog (version : Version_view.t) (other_versions : Version_row.t list) =
  ignore
  <$> Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "De-duplicate a version")
      [txt
        "Only do this if the two versions are actually the same, or if the other \
        one is a destructured version that can encompass this one.";
      Tables.versions
        other_versions
        ~onclick: (fun other_version ->
          let%lwt version = Option.get <$> Model.Version.get version.id in
          let%lwt other_version = Option.get <$> Model.Version.get other_version.id in
          confirmation_dialog ~this_version: version ~other_version;%lwt
          return (some ());
          lwt_unit
        );
      ]
      ~buttons: [
        Button.close' ~return ();
      ]
