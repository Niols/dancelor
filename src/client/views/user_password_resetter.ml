open Nes
open Components
open Js_of_ocaml
open Utils
open Html

type status = Match | Dont_match

let create username token =
  let%lwt password1_input =
    Input.make
      ~type_: Password
      ~label: "Password"
      ~placeholder: "1234567"
      ~serialise: Model.User.Password_clear.project
      ~validate: (S.const % fun password1 -> Result.bind (Password.check password1) @@ fun () -> Ok (Model.User.Password_clear.inject password1))
      ""
  in
  let%lwt password2_input =
    Input.make
      ~type_: Password
      ~label: "Password, again"
      ~placeholder: "1234678"
      ~serialise: Model.User.Password_clear.project
      ~validate: (fun password2 ->
        S.flip_map (Component.state password1_input) @@ fun password1 ->
        if password1 = password2 then Ok (Model.User.Password_clear.inject password2) else Error "The passwords do not match."
      )
      ""
  in
  let password =
    RS.bind (Component.signal password1_input) @@ fun password1 ->
    RS.bind (Component.signal password2_input) @@ fun password2 ->
    (* Cannot hurt to check twice. *)
    S.const @@ if password1 = password2 then Ok password2 else Error "The passwords do not match."
  in
  Page.make'
    ~title: (lwt "Reset password")
    [Input.inactive ~label: "Username" (Username.to_string username);
    Component.html password1_input;
    Component.html password2_input;
    ]
    ~buttons: [
      Button.make
        ~label: "Reset password"
        ~label_processing: "Resetting password..."
        ~classes: ["btn-primary"]
        ~disabled: (S.map Result.is_error password)
        ~onclick: (fun () ->
          Api.call_exn (User Reset_password) username token (Result.get_ok @@ S.value password);%lwt
          Toast.open_ ~title: "Password reset" [txt "Your password has been reset successfully. You may now try to sign in."];
          Dom_html.window##.history##replaceState "fixme-the-state" (Js.string "") (Js.some (Js.string "/"));
          Main_page.load_sleep_raise (Index.create ());%lwt
          lwt_unit
        )
        ();
    ]
