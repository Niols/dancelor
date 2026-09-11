open Nes
open Dancelor_common
open Model
open Model_new
open Search_new
open Html
open Utils

let subtitles_gen kind order conceptors = [
  span
    [
      txt (Kind.Dance.to_pretty_string kind);
      span (
        match order with
        | None -> []
        | Some order ->
          [
            txt " — Play ";
            txt (Set_order.to_pretty_string order);
          ]
      );
    ];
  span (
    match conceptors with
    | [] -> []
    | conceptors ->
      txt "Set by " :: Formatters_new.Person.names ~links: true conceptors
  );
]

let subtitles (set : Set_view.t) =
  subtitles_gen set.kind (Some set.order) set.conceptors

let actions (set : Set_view.t) = [
  lwt [
    Button.make
      ~label: "Download PDF"
      ~icon: (Other File_pdf)
      ~onclick: (fun _ -> ignore <$> Set_download_dialog.create_and_open set)
      ~dropdown: true
      ();
  ];
  (Add_to.button_to_book ~source_type: "set" ~source_format: Formatters_new.Set.name (Set_view.to_name set) (Model.Book.Set (set.id, Model.Set_parameters.none)));
  (
    lwt @@
      match Permission_new.edit_reason set.permission with
      | None -> []
      | Some _ ->
        [
          Button.make_a
            ~label: "Edit"
            ~icon: (Action Edit)
            ~href: (S.const @@ Endpoints.Page.(href @@ Set Edit) set.id)
            ~dropdown: true
            ();
          Action.delete
            ~onclick: (fun () -> Madge_client.call Endpoints.Api.(route @@ Set Delete) set.id)
            ~model: "set"
            ();
        ]
  );
]

let body_gen (content : (Version_row.t * Version_parameters.t) list) (id : Set_id.t option) = [
  div
    (
      List.mapi
        (fun index (version, params) ->
          let in_set = Option.map (fun id -> (id, index)) id in
          div
            ~a: [a_class ["mt-4"]]
            [
              div ~a: [a_class ["row"; "justify-content-between"; "mb-2"]] [
                div ~a: [a_class ["col"; "text-start"]] (
                  Formatters_new.Version.name_disambiguation_and_sources ?in_set version @
                    Formatters_new.Version.parameters (Some params)
                );
                div ~a: [a_class ["col"; "text-end"]] (
                  Formatters_new.Version.composer_and_arranger
                    ~short: true
                    version @
                    Formatters_new.Version.display_composer (Some params)
                );
              ];
              Components.Version_snippets.make ~show_audio: false ~params (Version_row.to_name version);
            ]
        )
        content
    );
  div (
    match id with
    | None -> []
    | Some id ->
      [
        quick_explorer_links [
          ("books containing this set", Any_query.specific_only (Any_query.Book (Book_query.make_specific ~contains_set: (Some [id]) ())));
        ];
      ]
  );
]

let body (set : Set_view.t) =
  body_gen set.content (Some set.id)

let view in_search id =
  Main_page.madge_call_or_404 (Set Get_view) id @@ fun set ->
  Page.make'
    ~parent_title: "Set"
    ~before_title: [Components.Context_links.for_search in_search (Any_id.Set id)]
    ~title: (lwt set.name)
    ~subtitles: (subtitles set)
    ~share_new: (Set id)
    ~actions: (actions set)
    (body set)
