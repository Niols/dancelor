open Nes
open Dancelor_common
open Model_new
open Search_new
open Html
open Utils

let dialog
    ~source_type
    ~target_type
    ~target_icon
    ~source_format
    ~target_format
    ~target_href
    ~(target_result : ?onclick: 'a -> ?in_search: 'b -> 'c -> 'd)
    ~target_search
    ~target_update
    ~target_history
    ~target_add_source_to_content
    source
  =
  let make_result ?in_search ~return target =
    target_result
      ?in_search
      target
      ~onclick: (fun () ->
        let target_value = target_add_source_to_content (Entry.value target) in
        ignore <$> target_update (Entry.id target) target_value (Entry.access target);%lwt
        Toast.open_
          ~title: (spf "Added to %s" target_type)
          [txtf "The %s " source_type;
          source_format source;
          txtf " has been added to %s " target_type;
          target_format target;
          txt " successfully.";
          ]
          ~buttons: [
            Button.make_a
              ~label: ("Go to " ^ target_type)
              ~icon: target_icon
              ~classes: ["btn-primary"]
              ~href: (S.const @@ target_href @@ Entry.id target)
              ();
          ];
        return (Some ());
        lwt_unit
      )
  in
  let quick_search =
    (* FIXME: filter only on the items that the user owns / is allowed to edit *)
    Components.Search.Quick.make ~search: target_search ()
  in
  let%lwt results_when_no_search =
    let%lwt targets = target_history () in
    List.take 10 % List.deduplicate <$> Lwt_list.filter_p (Option.is_some <%> Permission.can_update_private) targets
  in
  ignore
  <$> Page.open_dialog ~hide_body_overflow_y: true @@ fun return ->
    Components.Search.Quick.render
      ~return
      ~dialog_title: (lwt @@ spf "Add to %s" target_type)
      ~make_result: (make_result ~return)
      ~results_when_no_search
      quick_search

(** {!dialog} specialised for when the target is a book. *)
let dialog_to_book ~source_type ~source_format source source_page =
  dialog
    source
    ~source_type
    ~source_format
    ~target_type: "book"
    ~target_icon: Icon.(Model Book)
    ~target_format: Formatters.Book.name'
    ~target_href: Endpoints.Page.href_book
    ~target_result: (Any_result.make_book_result ?classes: None ?prefix: None ?suffix: None)
    ~target_search: (fun slice query ->
      match Book_query.parse query with
      | Error msg -> lwt_error msg
      | Ok query ->
        let%lwt books = Madge_client.call_exn Endpoints.Api.(route @@ Book Search) slice query in
        let%lwt items = Lwt_list.map_p (fun book -> Option.get <$> Model.Book.get book.Book_row.id) books.items in
        lwt_ok {books with items}
    )
    ~target_update: (Madge_client.call_exn Endpoints.Api.(route @@ Book Update))
    ~target_history: (fun () ->
      let%lwt books = History.get_books () in
      Lwt_list.map_p (fun book -> Option.get <$> Model.Book.get book.Book_row.id) books
    )
    ~target_add_source_to_content: (fun book ->
      let contents = Model.Book.contents book in
      Model.Book.set_contents (contents @ [source_page]) book
    )

let button ~target_type create_dialog =
  match%lwt Environment.actor with
  | None -> lwt_nil
  | Some actor ->
    lwt [
      Button.make
        ~label: (spf "Add to %s" target_type)
        ~label_processing: (spf "Adding to %s..." target_type)
        ~icon: (Action Add)
        ~dropdown: true
        ~onclick: (fun () -> create_dialog actor)
        ()
    ]

let button_to_book ~source_type ~source_format source source_page =
  button ~target_type: "book" (fun _user -> dialog_to_book ~source_type ~source_format source source_page)
