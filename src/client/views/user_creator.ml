open Nes
open Dancelor_common
open Components
open Html
open Utils

type status = Match | Dont_match

let open_token_result_dialog (user : User_row.t) token =
  ignore
  <$> Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "Created user")
      [p [
        txt "User ";
        txt (Id.to_string user.id);
        txt " was created successfully. Pass them the following link: ";
      ];
      p [
        let href = Endpoints.Page.(href @@ User Password_reset) user.username token in
        a ~a: [a_href href] [txt @@ Uri.to_string href]
      ];
      p [
        txt " for them to create a password.";
      ];
      ]
      ~buttons: [Button.ok' ~return ()]

let create () =
  Main_page.assert_can_admin @@ fun () ->
  let%lwt username_input =
    Input.make
      ~type_: Text
      ~placeholder: "JeanMilligan"
      ~label: "Username"
      ~serialise: Username.to_string
      ~validate: (S.const % Option.to_result ~none: "Invalid username format." % Username.from_string)
      ""
  in
  let%lwt email_input =
    Input.make
      ~type_: Text
      ~placeholder: "millijean1923@rscds.org"
      ~label: "Email"
      ~serialise: Email.to_string
      ~validate: (S.const % Option.to_result ~none: "Invalid email format." % Email.of_string)
      ""
  in
  let signal =
    RS.bind (Component.signal username_input) @@ fun username ->
    RS.bind (Component.signal email_input) @@ fun email ->
    S.const @@ Ok {User_create_form.username; email}
  in
  Page.make'
    ~title: (lwt "Create user")
    [Component.html username_input;
    Component.html email_input;
    ]
    ~buttons: [
      Button.make
        ~label: "Create user"
        ~label_processing: "Creating user..."
        ~classes: ["btn-primary"]
        ~disabled: (S.map Result.is_error signal)
        ~onclick: (fun () ->
          let user = Result.get_ok @@ S.value signal in
          let%lwt (user, token) = Api.call_exn (User Create) user in
          open_token_result_dialog user token;%lwt
          Component.clear username_input
        )
        ();
    ]
