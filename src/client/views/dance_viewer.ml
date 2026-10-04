open Nes
open Dancelor_common
open Html
open Utils

let subtitles dance = [
  span (Formatters.Dance.aka dance);
  span (Formatters.Dance.description dance);
]

let actions (dance : Dance_view.t) = [
  Add_to.button_to_book
    ~source_type: "dance"
    ~source_id: Dance_name.id
    ~source_format: Formatters.Dance.name
    Endpoints.Book.Add_dance_to_contents
    (Dance_view.to_name dance);
  (
    match%lwt Main_page.can_update_public () with
    | None -> lwt_nil
    | Some _ ->
      lwt [
        Button.make_a
          ~label: "Edit"
          ~icon: (Action Edit)
          ~href: (S.const @@ Endpoints.Page.(href @@ Dance Edit) dance.id)
          ~dropdown: true
          ();
      ]
  );
  (
    match%lwt Main_page.can_delete_public () with
    | None -> lwt_nil
    | Some _ ->
      lwt [
        Action.delete
          ~onclick: (fun () -> Api.call (Dance Delete) dance.id)
          ~model: "dance"
          ();
      ]
  );
  (lwt @@ Option.map_to_list (Action.scddb Dance) dance.scddb_id);
]

let body (dance : Dance_view.t) = [
  div
    (
      match dance.two_chords with
      | One_chord -> []
      | Two_chords -> [txt "Two Chords"]
      | Dont_know -> [txt "Two Chords: unknown"]
    );
  div
    (
      match dance.date with
      | None -> []
      | Some date -> [txt "Devised "; txt (PartialDate.to_pretty_string ~at: true date); txt "."]
    );
  div
    [
      h3 [txt "Recommended Tunes"];
      (
        match dance.tunes with
        | [] ->
          txt @@
          "There are no recommended tunes for this dance. " ^
          "Dancelor is not all-knowing: go check the Strathspey Database! " ^
          "And if you find something that is not known here, report it to someone."
        | tunes -> Tables.tunes tunes
      );
    ];
]

let view in_search id =
  Main_page.madge_call_or_404 (Dance Get_view) id @@ fun dance ->
  Page.make'
    ~parent_title: "Dance"
    ~before_title: [Components.Context_links.for_search in_search (Any_id.Dance id)]
    ~title: (lwt dance.name)
    ~subtitles: (subtitles dance)
    ~share: (Sharing_dialog.copy_link_button @@ Dance id)
    ~actions: (actions dance)
    (body dance)
