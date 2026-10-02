open Nes
open Dancelor_common
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

(* /!\ deduplicate this version INTO the other version *)
let confirmation_dialog ~this_version_id ~other_version_id =
  let%lwt this_version = Api.call_exn (Version Get_form) this_version_id in
  let%lwt other_version = Api.call_exn (Version Get_form) other_version_id in
  let (get_changes_actions, get_changes_html, add_changes) = make_change_trackers () in

  (* changes to other version *)
  let%lwt () =
    let (_, get_other_version_changes, add_other_version_changes) =
      make_change_trackers ()
    in
    (* tune *)
    if not (Entry.Id.equal' this_version.tune.id other_version.tune.id) then
      failwith "Version de-duplicator: these two versions do not share the same tune.";
    let the_tune = other_version.tune in
    (* key *)
    if this_version.key <> other_version.key then
      failwith "Version de-duplicator: these two versions do not share the same key.";
    let the_key = other_version.key in
    (* FIXME: can do better? *)
    (* sources *)
    (
      match this_version.sources with
      | [] -> ()
      | _ ->
        add_other_version_changes [
          txt "add the following sources:";
          ul (
            List.map
              (fun source ->
                li [
                  Formatters_new.Source.name (Version_form.source_to_name source);
                  txtf " (%s)" (NEString.to_string @@ Model_builder.Core.Version.Structure.to_string source.structure);
                ]
              )
              this_version.sources
          );
        ]
    );
    let the_sources = other_version.sources @ this_version.sources in
    (* arrangers *)
    if this_version.arrangers <> other_version.arrangers then
      failwith "Version de-duplicator: these two versions do not share the same arrangers.";
    let the_arrangers = other_version.arrangers in
    (* FIXME: can do better? *)
    (* remark *)
    if this_version.remark <> other_version.remark then
      failwith "Version de-duplicator: these two versions do not share the same remark.";
    let the_remark = other_version.remark in
    (* FIXME: can do better? *)
    (* disambiguation *)
    if this_version.disambiguation <> other_version.disambiguation then
      failwith "Version de-duplicator: these two versions do not share the same disambiguation.";
    let the_disambiguation = other_version.disambiguation in
    (* FIXME: can do better? *)
    (* content *)
    add_other_version_changes [txt "use its content; the content of the current version will be lost entirely."];
    let the_content = other_version.content in
    (* that's it for changes to the other version; bundle them together as a change *)
    let other_version_formatted =
      span (
        Formatters_new.Version.name_disambiguation_and_sources (Version_form.to_row other_version_id other_version) @ [
          txt " [";
          Formatters_new.Version.id other_version_id;
          txt "]"
        ]
      )
    in
    (
      match get_other_version_changes () with
      | [] ->
        add_changes [txt "This will not change anything to the other version, "; other_version_formatted; txt "."];
      | changes ->
        add_changes
          ~action: (fun () ->
            ignore
            <$> Api.call_exn
                (Version Update)
                other_version_id
                {
                  Version_form.tune =
                  the_tune;
                  key = the_key;
                  sources = the_sources;
                  arrangers = the_arrangers;
                  remark = the_remark;
                  disambiguation = the_disambiguation;
                  content = the_content;
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
  let replace_version (a_version : Version_row.t) =
    if Entry.Id.equal' a_version.id this_version_id then
        (Version_form.to_row other_version_id other_version)
    else
      a_version
  in

  (* changes to sets *)
  let%lwt sets =
    Search_result.items
    <$> Api.call_exn (Set Search) Slice.everything @@
        Query.make ~specific: (Set_query.make_specific ~contains_version: (Some [this_version_id]) ()) ()
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
          let contents = List.map (Pair.map_fst replace_version) set.Set_form.contents in
          ignore <$> Api.call_exn (Set Update) id {set with contents}
        )
        [txt "replace the version in set "; Formatters_new.Set.name (Set_form.to_name id set); txt "."]
    )
    sets;

  (* changes to books *)
  let%lwt books =
    Search_result.items
    <$> Api.call_exn (Book Search) Slice.everything @@
        Query.make ~specific: (Book_query.make_specific ~contains_version: (Some [this_version_id]) ()) ()
  in
  let%lwt books =
    Lwt_list.map_p
      (fun {Book_row.id; _} -> Pair.cons id <$> Api.call_exn (Book Get_form) id)
      books
  in
  List.iter
    (fun (id, book) ->
      add_changes
        ~action: (fun () ->
          let contents =
            List.map
              (function
                | Book_form.Dance (dance, Dance_versions versions_and_params) ->
                  Book_form.Dance (dance, Dance_versions (NEList.map (Pair.map_fst replace_version) versions_and_params))
                | Book_form.Versions versions_and_params ->
                  Book_form.Versions (NEList.map (Pair.map_fst replace_version) versions_and_params)
                | page -> page
              )
              book.Book_form.contents
          in
          ignore <$> Api.call_exn (Book Update) id {book with contents}
        )
        [
          txt "replace the version in book ";
          Formatters_new.Book.name (Book_form.to_name id book);
          txt "."
        ]
    )
    books;

  (* removal of the current version *)
  add_changes
    ~action: (fun () -> ignore <$> Api.call_exn (Version Delete) this_version_id)
    (
      [txt "delete the current version, "] @
      Formatters_new.Version.name_disambiguation_and_sources (Version_form.to_row this_version_id this_version) @ [
        txt " [";
        Formatters_new.Version.id this_version_id;
        txt "].";
      ]
    );

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
          ~href: (S.const @@ Endpoints.Page.href_version other_version_id)
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
          confirmation_dialog
            ~this_version_id: version.id
            ~other_version_id: other_version.id;%lwt
          return (some ());
          lwt_unit
        );
      ]
      ~buttons: [
        Button.close' ~return ();
      ]
