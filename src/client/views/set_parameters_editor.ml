open Nes
open Components
open Html

let editor =
  let open Bundle in
  Input.prepare_option
    ~type_: Text
    ~label: "Display name"
    ~placeholder: "eg. The Cairdin o' It"
    ~serialise: id
    ~validate: (S.const % ok)
    () ^::
    nil

let assemble (display_name, ()) =
  Model.Set_parameters.make ?display_name ()

let disassemble params =
  let display_name = Model.Set_parameters.display_name params in
  lwt (display_name, ())

let e =
  Editor.prepare_nosubmit
    ~key: "set parameters"
    ~icon: (Other Bug)
    (* FIXME: unused? *)
    editor
    ~assemble
    ~disassemble
    ~check_result: Model.Set_parameters.equal
    ~format: (fun _ -> assert false)
    ~href: (fun _ -> assert false)

let empty_value () = Editor.result_to_state e Model.Set_parameters.none
