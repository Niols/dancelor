open Nes
open Components
open Html

let editor =
  let open Bundle in
  group
    ~wrap: (fun (display_name, ()) ->
      Model.Set_parameters.make ?display_name ()
    )
    ~unwrap: (fun params ->
      let display_name = Model.Set_parameters.display_name params in
        (display_name, ())
    )
    ~check: Model.Set_parameters.equal
    (
      Input.prepare_option
        ~type_: Text
        ~label: "Display name"
        ~placeholder: "eg. The Cairdin o' It"
        ~serialise: id
        ~validate: (S.const % ok)
        () ^::
        nil
    )

let e =
  Editor.prepare_nosubmit
    ~key: "set parameters"
    ~icon: (Other Bug)
    ~format: (fun _ -> assert false)
    ~href: (fun _ -> assert false)
    editor

let empty_value () = Editor.result_to_state e Model.Set_parameters.none
