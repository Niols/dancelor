open Nes
open Dancelor_common
open Html
open Utils

type sign_in_dialog_status = Dont_know | Invalid

let open_sign_in_dialog () =
  let open Components in
  let (status_signal, set_status_signal) = S.create Dont_know in
  let%lwt username_input =
    Input.make
      ~type_: Text
      ~label: "Username"
      ~placeholder: "JeanMilligan"
      ~oninput: (fun _ -> set_status_signal Dont_know)
      ~serialise: Username.to_string
      ~validate: (fun username ->
        Fun.flip S.map status_signal @@ fun status ->
        match Username.from_string username with
        | None -> Error "Invalid username format."
        | Some username ->
          match status with
          | Invalid -> Error "Invalid username or password."
          | Dont_know -> Ok username
      )
      ""
  in
  let%lwt password_input =
    Input.make
      ~type_: Password
      ~label: "Password"
      ~placeholder: "1234567"
      ~oninput: (fun _ -> set_status_signal Dont_know)
      ~serialise: Password_clear.project
      ~validate: (fun password ->
        S.bind status_signal @@ fun status ->
        S.const @@
          match password, status with
          | "", _ -> Error "The password cannot be empty."
          | _, Invalid -> Error "Invalid username or password."
          | _, Dont_know -> Ok (Password_clear.inject password)
      )
      ""
  in
  let%lwt remember_me_input =
    Choices.(
      make_radios
        ~label: "Sign in..."
        [
          choice [txt "Just this once"] ~value: false ~checked: true;
          choice [txt "Remember me"] ~value: true;
        ]
    )
  in
  let request_signal =
    S.map Result.to_option @@
    RS.bind (Component.signal username_input) @@ fun username ->
    RS.bind (Component.signal password_input) @@ fun password ->
    RS.bind (Component.signal remember_me_input) @@ fun remember_me ->
    RS.pure (username, password, remember_me)
  in
  let%lwt _ =
    Page.open_dialog @@ fun return ->
    Page.make'
      ~title: (lwt "Sign in")
      ~on_load: (fun () -> Component.focus username_input)
      [Component.html username_input;
      Component.html password_input;
      Component.html remember_me_input;
      ]
      ~buttons: [
        Button.cancel' ~return ();
        Button.make
          ~label: "Sign in"
          ~label_processing: "Signing in..."
          ~icon: (Other Sign_in)
          ~classes: ["btn-primary"]
          ~disabled: (S.map Option.is_none request_signal)
          ~onclick: (fun () ->
            Option.fold
              (S.value request_signal)
              ~none: lwt_unit
              ~some: (fun (username, password, remember_me) ->
                set_status_signal Dont_know;
                match%lwt Api.call_exn (User Sign_in) username password remember_me with
                | None -> set_status_signal Invalid; lwt_unit
                | Some _ -> return (Some ()); lwt_unit
              )
          )
          ();
      ]
  in
  Js_of_ocaml.Dom_html.window##.location##reload;
  lwt_unit

let sign_out () =
  Api.call_exn (User Sign_out);%lwt
  Js_of_ocaml.Dom_html.window##.location##reload;
  lwt_unit

let set_omniscience enable =
  let%lwt _ = Api.call (User Set_omniscience) enable in
  Toast.open_
    ~type_: Forever
    ~title: "Omniscience"
    [txtf "Omniscience has been %s. You should reload for it to take effect." (if enable then "enabled" else "disabled")]
    ~buttons: [
      Button.make
        ~label: "Reload"
        ~icon: (Other Reload)
        ~classes: ["btn-primary"]
        ~onclick: (fun () -> Js_of_ocaml.Dom_html.window##.location##reload; lwt_unit)
        ();
    ];
  lwt_unit

let header_item =
  R.li
    ~a: [
      R.a_class
        (
          S.from_lwt ["nav-item"] @@
          Lwt.flip_map Environment.actor @@ function
          | None -> ["nav-item"]
          | Some _ -> ["nav-item"; "dropdown"]
        );
    ]
    (
      S.from_lwt [
        Button.make
          ~label: "Sign in"
          ~icon: (Other Sign_in)
          ~classes: ["disabled"; "placeholder"]
          ()
      ] @@
      Lwt.flip_map Environment.actor @@ function
      | None ->
        [
          Button.make
            ~label: "Sign in"
            ~icon: (Other Sign_in)
            ~classes: ["text-white"]
            ~onclick: open_sign_in_dialog
            ()
        ]
      | Some actor ->
        [
          Button.make
            ~label: (Username.to_string actor.username)
            ~icon: (Model User)
            ~classes: ["text-white"; "dropdown-toggle"]
            ~more_a: [a_user_data "bs-toggle" "dropdown"; a_aria "expanded" ["false"]]
            ();
          ul
            ~a: [a_class ["dropdown-menu"]]
            (
              List.flatten
                [
                  (
                    if actor.role = Administrator then
                      [
                        li [
                          Button.make_a
                            ~label: "Create user"
                            ~icon: (Action Add)
                            ~dropdown: true
                            ~href: (S.const @@ Endpoints.Page.(href @@ User Create))
                            ()
                        ];
                        li [
                          Button.make_a
                            ~label: "Reset user password"
                            ~icon: (Action Edit)
                            ~dropdown: true
                            ~href: (S.const @@ Endpoints.Page.(href @@ User Prepare_reset_password))
                            ()
                        ];
                        li [
                          if actor.role = Administrator && actor.omniscience then
                            Button.make
                              ~label: "Disable omniscience"
                              ~icon: (Access Omniscient_administrator)
                              ~dropdown: true
                              ~onclick: (fun () -> set_omniscience false)
                              ()
                          else
                            Button.make
                              ~label: "Enable omniscience"
                              ~icon: (Access Non_omniscient_administrator)
                              ~dropdown: true
                              ~onclick: (fun () -> set_omniscience true)
                              ()
                        ];
                        li [hr ~a: [a_class ["dropdown-divider"]] ()];
                      ]
                    else []
                  );
                  [R.li (
                    S.from_lwt [] @@
                      match%lwt Environment.person_id with
                      | None -> lwt_nil
                      | Some person_id ->
                        lwt [
                          Button.make_a
                            ~label: "My person"
                            ~icon: (Model Person)
                            ~dropdown: true
                            ~href: (S.const (Endpoints.Page.(href (Person View) None) person_id))
                            ()
                        ]
                  );
                  li [
                    Button.make
                      ~label: "Sign out"
                      ~icon: (Other Sign_out)
                      ~dropdown: true
                      ~onclick: sign_out
                      ()
                  ];
                  ];
                ]
            );
        ]
    )
