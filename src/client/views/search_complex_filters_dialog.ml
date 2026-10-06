open Nes
open Dancelor_common
open Html
open Utils
open Components

let type_choices (type_ : Any_id.Type.t option) =
  Choices.(
    make_radios
      ~label: "Type"
      [
        choice' [txt "All"] ~checked: (Option.is_none type_);
        choice' [txt "Person"] ~value: Any_id.Type.Person ~checked: (type_ = Some Any_id.Type.Person);
        choice' [txt "Dance"] ~value: Any_id.Type.Dance ~checked: (type_ = Some Any_id.Type.Dance);
        choice' [txt "Source"] ~value: Any_id.Type.Source ~checked: (type_ = Some Any_id.Type.Source);
        choice' [txt "Tune"] ~value: Any_id.Type.Tune ~checked: (type_ = Some Any_id.Type.Tune);
        choice' [txt "Version"] ~value: Any_id.Type.Version ~checked: (type_ = Some Any_id.Type.Version);
        choice' [txt "Set"] ~value: Any_id.Type.Set ~checked: (type_ = Some Any_id.Type.Set);
        choice' [txt "Book"] ~value: Any_id.Type.Book ~checked: (type_ = Some Any_id.Type.Book);
        choice' [txt "User"] ~value: Any_id.Type.User ~checked: (type_ = Some Any_id.Type.User);
        choice' [txt "Group"] ~value: Any_id.Type.Group ~checked: (type_ = Some Any_id.Type.Group);
      ]
  )

let make_person_specific_choices (_query : Person_query.specific option) = (S.const (), [])

let make_dance_specific_choices (_query : Dance_query.specific option) = (S.const {Dance_query.deviser = None}, [])

let make_source_specific_choices (_query : Source_query.specific option) = (S.const {Source_query.editor = None}, [])

let make_set_specific_choices (_query : Set_query.specific option) = (S.const {Set_query.conceptor = None; contains_version = None; contains_tune = None}, [])

let make_book_specific_choices (_query : Book_query.specific option) = (S.const {Book_query.author = None; contains_version = None; contains_tune = None; contains_set = None}, [])

let make_tune_specific_choices (query : Tune_query.specific option) =
  let%lwt kind_choices =
    let checked kind =
      match query with
      | Some {kind = Some kinds; _} -> List.mem kind kinds
      | _ -> false
    in
    let open Choices in
    make_checkboxes ~label: "Kind" @@
      List.map
        (fun kind ->
          choice [txt (Kind.Base.to_long_string ~capitalised: true kind)] ~value: kind ~checked: (checked kind)
        )
        Kind.Base.all
  in
  let query =
    S.bind (S.map Result.get_ok @@ Component.signal kind_choices) @@ fun kind ->
    S.const {
      Tune_query.kind = if kind = [] then None else Some kind;
      composer = None; (* FIXME *)
    }
  in
  let html = [
    Component.inner_html kind_choices;
  ]
  in
  lwt (query, html)

let major_keys =
  let open Music in
  List.map
    (flip Key.make Major)
    [
      Pitch.make C Natural 0;
      Pitch.make G Natural 0;
      Pitch.make D Natural 0;
      Pitch.make A Natural 0;
      Pitch.make E Natural 0;
      Pitch.make B Natural 0;
      Pitch.make F Sharp 0;
      Pitch.make C Sharp 0;
      Pitch.make F Natural 0;
      Pitch.make B Flat 0;
      Pitch.make E Flat 0;
      Pitch.make A Flat 0;
      Pitch.make D Flat 0;
    ]

let major_key_choices (query : Version_query.specific option) =
  let checked key =
    match query with
    | Some {key = Some keys; _} -> List.mem key keys
    | _ -> false
  in
  Choices.(
    make_checkboxes
      ~label: "Major keys"
      (
        List.map
          (fun key ->
            choice [txt (Music.Key.to_pretty_string key)] ~value: key ~checked: (checked key)
          )
          major_keys
      )
  )

let minor_keys =
  let open Music in
  List.map
    (flip Key.make Minor)
    [
      Pitch.make A Natural 0;
      Pitch.make E Natural 0;
      Pitch.make B Natural 0;
      Pitch.make F Sharp 0;
      Pitch.make C Sharp 0;
      Pitch.make G Sharp 0;
      Pitch.make D Sharp 0;
      Pitch.make A Sharp 0;
      Pitch.make D Natural 0;
      Pitch.make G Natural 0;
      Pitch.make C Natural 0;
      Pitch.make F Natural 0;
      Pitch.make B Flat 0;
    ]

let minor_key_choices (query : Version_query.specific option) =
  let checked key =
    match query with
    | Some {key = Some keys; _} -> List.mem key keys
    | _ -> false
  in
  Choices.(
    make_checkboxes
      ~label: "Minor keys"
      (
        List.map
          (fun key ->
            choice [txt (Music.Key.to_pretty_string key)] ~value: key ~checked: (checked key)
          )
          minor_keys
      )
  )

let make_version_specific_choices ~tune_query ~tune_html (query : Version_query.specific option) =
  let%lwt major_key_choices = major_key_choices query in
  let%lwt minor_key_choices = minor_key_choices query in
  let key =
    S.l2
      (@)
      (S.map Result.get_ok (Component.signal major_key_choices))
      (S.map Result.get_ok (Component.signal minor_key_choices))
  in
  let query =
    S.bind tune_query @@ fun tune ->
    S.bind key @@ fun key ->
    S.const {
      Version_query.tune;
      key = if key = [] then None else Some key;
      source = None; (* FIXME *)
    }
  in
  let html =
    tune_html @ [
      Component.inner_html major_key_choices;
      Component.inner_html minor_key_choices;
    ]
  in
  lwt (query, html)

let make_user_specific_choices (_query : User_query.specific option) = (S.const (), [])

let make_group_specific_choices (_query : Group_query.specific option) = (S.const (), [])

let make_common_choices (query : Query.common) = (S.const {Query.terms = query.terms}, [])

(* the dialog itself *)

let open_ (query : Any_query.t) =
  let (type_, person_query, dance_query, source_query, tune_query, version_query, set_query, book_query, user_query, group_query) =
    match query.specific with
    | None -> (None, None, None, None, None, None, None, None, None, None)
    | Some Person person_query -> (Some Any_id.Type.Person, Some person_query, None, None, None, None, None, None, None, None)
    | Some Dance dance_query -> (Some Any_id.Type.Dance, None, Some dance_query, None, None, None, None, None, None, None)
    | Some Source source_query -> (Some Any_id.Type.Source, None, None, Some source_query, None, None, None, None, None, None)
    | Some Tune tune_query -> (Some Any_id.Type.Tune, None, None, None, Some tune_query, None, None, None, None, None)
    | Some Version version_query -> (Some Any_id.Type.Version, None, None, None, Some version_query.tune, Some version_query, None, None, None, None)
    | Some Set set_query -> (Some Any_id.Type.Set, None, None, None, None, None, Some set_query, None, None, None)
    | Some Book book_query -> (Some Any_id.Type.Book, None, None, None, None, None, None, Some book_query, None, None)
    | Some User user_query -> (Some Any_id.Type.User, None, None, None, None, None, None, None, Some user_query, None)
    | Some Group group_query -> (Some Any_id.Type.Group, None, None, None, None, None, None, None, None, Some group_query)
  in
  let%lwt type_choices = type_choices type_ in
  let (person_query, person_html) = make_person_specific_choices person_query in
  let (dance_query, dance_html) = make_dance_specific_choices dance_query in
  let (source_query, source_html) = make_source_specific_choices source_query in
  let (book_query, book_html) = make_book_specific_choices book_query in
  let (set_query, set_html) = make_set_specific_choices set_query in
  let%lwt (tune_query, tune_html) = make_tune_specific_choices tune_query in
  let%lwt (version_query, version_html) = make_version_specific_choices version_query ~tune_query ~tune_html in
  let (user_query, user_html) = make_user_specific_choices user_query in
  let (group_query, group_html) = make_group_specific_choices group_query in
  let (common_query, common_html) = make_common_choices query.common in
  let specific =
    S.bind (S.map Result.get_ok @@ Component.signal type_choices) @@ function
      | None -> S.const None
      | Some Person -> S.map (some % Any_query.person) person_query
      | Some User -> S.map (some % Any_query.user) user_query
      | Some Dance -> S.map (some % Any_query.dance) dance_query
      | Some Source -> S.map (some % Any_query.source) source_query
      | Some Tune -> S.map (some % Any_query.tune) tune_query
      | Some Version -> S.map (some % Any_query.version) version_query
      | Some Set -> S.map (some % Any_query.set) set_query
      | Some Book -> S.map (some % Any_query.book) book_query
      | Some Group -> S.map (some % Any_query.group) group_query
  in
  let new_query =
    S.bind common_query @@ fun common ->
    S.bind specific @@ fun specific ->
    S.const {Query.common; specific}
  in
  Page.open_dialog @@ fun return ->
  Page.make'
    ~title: (lwt "Complex filters")
    [div
      ~a: [a_class ["d-flex"; "justify-content-center"]]
      [
        Component.inner_html type_choices
      ];
    hr ();
    R.div
      ~a: [a_class ["d-flex"; "justify-content-center"]]
      (
        S.flip_map (S.map Result.get_ok (Component.signal type_choices)) @@ function
          | None -> []
          | Some Person -> person_html
          | Some Dance -> dance_html
          | Some Source -> source_html
          | Some Book -> book_html
          | Some Set -> set_html
          | Some Tune -> tune_html
          | Some Version -> version_html
          | Some User -> user_html
          | Some Group -> group_html
      );
    hr ();
    div ~a: [a_class ["d-flex"; "justify-content-center"]] common_html;
    ]
    ~buttons: [
      Button.cancel ~onclick: (fun () -> return None; lwt_unit) ();
      Button.clear ~onclick: (fun () -> lwt @@ return @@ Some Any_query.empty) ();
      Button.make
        ~label: "Apply"
        ~label_processing: "Applying..."
        ~icon: (Action Apply)
        ~classes: ["btn-primary"]
        ~onclick: (fun () -> return (some @@ S.value new_query); lwt_unit)
        ()
    ]

let open_error msg =
  Page.open_dialog' @@ fun return ->
  Page.make'
    ~title: (lwt "Complex filters")
    [p [txtf "It is not possible to open the filter dialog when the search text isn't valid. The search text is: %s" msg]]
    ~buttons: [
      a
        ~a: [
          a_class ["button"];
          a_onclick (fun _ -> return (); false);
        ]
        [txt "OK"];
    ]

let open_ text =
  match Any_query.parse text with
  | Error msg -> const None <$> open_error msg
  | Ok query -> open_ query
