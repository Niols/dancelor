open Nes
open Dancelor_common
open Html
open Utils

let view id =
  Main_page.madge_call_or_404 (Group Get_view) id @@ fun group ->
  Page.make'
    ~parent_title: "Group"
    ~title: (lwt group.name)
    ~actions: [
      (
        match%lwt Main_page.can_update_public () with
        | None -> lwt_nil
        | Some _ ->
          lwt [
            Button.make_a
              ~label: "Edit"
              ~icon: (Action Edit)
              ~href: (S.const @@ Endpoints.Page.(href @@ Group Edit) id)
              ~dropdown: true
              ();
          ]
      );
    ]
    [
      Tables.users group.members;
    ]
