open Nes
open Dancelor_common
open Model_builder.Core
open Components
open Html

let editor =
  let open Bundle in
  group
    ~wrap: (fun (display_name, (display_composer, (structure, (first_bar, (transposition, ()))))) ->
      Version_parameters.make ?display_name ?display_composer ?structure ?first_bar ?transposition ()
    )
    ~unwrap: (fun params ->
      let display_name = Version_parameters.display_name params in
      let display_composer = Version_parameters.display_composer params in
      let structure = Version_parameters.structure params in
      let first_bar = Version_parameters.first_bar params in
      let transposition = Version_parameters.transposition params in
        (display_name, (display_composer, (structure, (first_bar, (transposition, ())))))
    )
    ~check: Version_parameters.equal
    (
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
        ~serialise: Version_parameters.maybe_structure_to_string
        ~validate: (S.const % Option.to_result ~none: "not a valid structure" % Version_parameters.maybe_structure_of_string)
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
        ~serialise: (NEString.of_string_exn % string_of_int % Music.Transposition.to_semitones)
        ~validate: (S.const % Option.to_result ~none: "Not a number of semitones" % Option.map Music.Transposition.from_semitones % int_of_string_opt % NEString.to_string)
        () ^::
      nil
    )

let e =
  Editor.prepare_nosubmit
    ~key: "version parameters"
    ~icon: (Other Bug)
    ~format: (fun _ -> assert false)
    ~href: (fun _ -> assert false)
    editor

let empty_value () = Editor.result_to_state e Version_parameters.none
