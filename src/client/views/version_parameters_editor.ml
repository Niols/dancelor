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
  Input.prepare_option
    ~type_: Text
    ~label: "Display composer"
    ~placeholder: "eg. Niel Gow"
    ~serialise: id
    ~validate: (S.const % ok)
    () ^::
  Input.prepare_option
    ~type_: Text
    ~label: "Structure"
    ~placeholder: "eg. AABB or ABABB"
    ~serialise: Model.Version_parameters.maybe_structure_to_string
    ~validate: (S.const % Option.to_result ~none: "not a valid structure" % Model.Version_parameters.maybe_structure_of_string)
    () ^::
  Input.prepare_option
    ~type_: Text
    ~label: "First bar"
    ~placeholder: "eg. 33"
    ~serialise: (NEString.of_string_exn % string_of_int)
    ~validate: (S.const % Option.to_result ~none: "Not a number" % int_of_string_opt % NEString.to_string)
    () ^::
  Input.prepare_option
    ~type_: Text
    ~label: "Transposition (number of semitones)"
    ~placeholder: "eg. +2 or -4"
    ~serialise: (NEString.of_string_exn % string_of_int % Dancelor_common.Transposition.to_semitones)
    ~validate: (S.const % Option.to_result ~none: "Not a number of semitones" % Option.map Dancelor_common.Transposition.from_semitones % int_of_string_opt % NEString.to_string)
    () ^::
  nil

let assemble (display_name, (display_composer, (structure, (first_bar, (transposition, ()))))) =
  Model.Version_parameters.make ?display_name ?display_composer ?structure ?first_bar ?transposition ()

let disassemble params =
  let display_name = Model.Version_parameters.display_name params in
  let display_composer = Model.Version_parameters.display_composer params in
  let structure = Model.Version_parameters.structure params in
  let first_bar = Model.Version_parameters.first_bar params in
  let transposition = Model.Version_parameters.transposition params in
  lwt (display_name, (display_composer, (structure, (first_bar, (transposition, ())))))

let e =
  Editor.prepare_nosubmit
    ~key: "version parameters"
    ~icon: (Other Bug)
    (* FIXME: unused? *)
    editor
    ~assemble
    ~disassemble
    ~check_result: Model.Version_parameters.equal
    ~format: (fun _ -> assert false)
    ~href: (fun _ -> assert false)

let empty_value () = Editor.result_to_state e Model.Version_parameters.none
