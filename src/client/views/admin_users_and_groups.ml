open Nes
open Dancelor_common
open Components
open Utils
open Html

let view () =
  let search =
    Search.make
      ~search: Api.principal_search
      ~pagination_mode: (Pagination ())
      ()
  in
  Page.make'
    ~title: (lwt "Users and groups")
    ~on_load: (fun () -> Search_bar.focus @@ Search.search_bar search)
    [
      section ~a: [a_class ["mb-4"]] [
        h3 [txt "Actions"];
        div [
          Button.make_a
            ~label: "Create user"
            ~icon: (Action Add)
            ~classes: ["btn-secondary"]
            ~href: (S.const @@ Endpoints.Page.(href @@ User Create))
            ();
          txt " ";
          Button.make_a
            ~label: "Create group"
            ~icon: (Action Add)
            ~classes: ["btn-secondary"]
            ~href: (S.const @@ Endpoints.Page.(href @@ Group Create))
            ();
          txt " ";
          Button.make_a
            ~label: "Reset user password"
            ~icon: (Action Edit)
            ~classes: ["btn-secondary"]
            ~href: (S.const @@ Endpoints.Page.(href @@ User Prepare_reset_password))
            ();
        ];
      ];
      section [
        h3 [txt "List and search"];
        Search.render
          search
          ~make_result: (fun ?in_search result -> Tables.entity_row ?in_search result);
      ];
    ]
