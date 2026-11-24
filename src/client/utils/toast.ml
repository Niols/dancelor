open Nes
open Html
open Js_of_ocaml

let stack =
  let dom_elt = ref None in
  fun () ->
    match !dom_elt with
    | Some elt -> elt
    | None ->
      let elt = To_dom.of_div @@ div ~a: [a_class ["toast-container"; "position-fixed"; "top-0"; "end-0"; "p-3"]] [] in
      dom_elt := Some elt;
      Dom.appendChild Dom_html.document##.body elt;
      elt

type type_ = Short | Forever

let open_ ?(type_ = Short) ~title ?(buttons = []) content =
  let start = Unix.time () in
  let toast =
    To_dom.of_div @@
      div
        ~a: [a_class ["toast"; "fade"; "show"]; a_role ["alert"]; a_aria "live" ["assertive"]; a_aria "atomic" ["true"]]
        [
          div
            ~a: [a_class ["toast-header"]]
            [
              h6 ~a: [a_class ["me-auto"; "my-0"]] [txt title];
              small [R.txt (Time_utils.ago_s start)];
              button ~a: [a_button_type `Button; a_class ["btn-close"]; a_user_data "bs-dismiss" "toast"; a_aria "label" ["Close"]] [];
            ];
          div ~a: [a_class ["toast-body"]] (
            content @ [
              div ~a: [a_class ["mt-2"; "pt-2"; "border-top"; "text-end"]] (
                List.intersperse
                  (txt " ")
                  (Button.close ~more_a: [a_user_data "bs-dismiss" "toast"] () :: buttons)
              )
            ]
          );
        ]
  in
  (
    match type_ with
    | Short ->
      Lwt.async (fun () ->
        Js_of_ocaml_lwt.Lwt_js.sleep 5.;%lwt
        Dom.removeChild (stack ()) toast;
        lwt_unit
      )
    | Forever -> ()
  );
  Dom.appendChild (stack ()) toast
