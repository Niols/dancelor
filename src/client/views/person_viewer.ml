open Nes
open Dancelor_common
open Model_new
open Search_new
open Html
open Utils

let view in_search id =
  Main_page.madge_call_or_404 (Person Get_view) id @@ fun person ->
  Page.make'
    ~parent_title: "Person"
    ~before_title: [Components.Context_links.for_search in_search (Any_id.Person id)]
    ~title: (lwt person.name)
    ~share: (Person id)
    ~actions: [
      (
        match%lwt Permission.can_update_public_new person with
        | None -> lwt_nil
        | Some _ ->
          lwt [
            Button.make_a
              ~label: "Edit"
              ~icon: (Action Edit)
              ~href: (S.const @@ Endpoints.Page.(href @@ Person Edit) id)
              ~dropdown: true
              ();
          ]
      );
      (
        match%lwt Permission.can_delete_public_new person with
        | None -> lwt_nil
        | Some _ ->
          lwt [
            Action.delete
              ~model: "person"
              ~onclick: (fun () -> Madge_client.call Endpoints.Api.(route @@ Person Delete) id)
              ();
          ]
      );
      (lwt @@ Option.map_to_list (Action.scddb Person) person.scddb_id);
    ]
    [
      div (
        if person.composed_tunes_are_public then
          [
            txt
              "This person indicates that the tunes they compose can be made \
               publicly available on Dancelor."
          ]
        else []
      );
      div (
        if person.published_tunes_are_public then
          [
            txt
              "This person indicates that the tunes they publish can be made \
               publicly available on Dancelor."
          ]
        else []
      );
      quick_explorer_links [
        ("tunes they composed", Any_query.specific_only (Any_query.Tune (Tune_query.make_specific ~composer: (Some [person.id]) ())));
        ("versions of tunes they composed", Any_query.specific_only (Any_query.Version (Version_query.make_specific ~tune: (Tune_query.make_specific ~composer: (Some [person.id]) ()) ())));
        ("dances they devised", Any_query.specific_only (Any_query.Dance (Dance_query.make_specific ~deviser: (Some [person.id]) ())));
        ("sets they conceived", Any_query.specific_only (Any_query.Set (Set_query.make_specific ~conceptor: (Some [person.id]) ())));
        ("books they edited", Any_query.specific_only (Any_query.Book (Book_query.make_specific ~author: (Some [person.id]) ())));
        ("sources they edited", Any_query.specific_only (Any_query.Source (Source_query.make_specific ~editor: (Some [person.id]) ())));
      ];
    ]
