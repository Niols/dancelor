open Nes
open Model_new

(** {2 Results} *)

module type Type = sig
  type t
  [@@deriving yojson]
end

module Search_result = struct
  type 'a t = {
    total: int;
    items: 'a list; [@default []]
  }
  [@@deriving yojson, fields]

  let map f {total; items} = {total; items = List.map f items}
end

module Make_search_result (X : Type) = struct
  type t = X.t Search_result.t
  [@@deriving yojson]
end

module Search_context_result = struct
  (** Invariant: if [next] (resp. [previous]) is empty, then the
      element is the last (resp. first) of the search results. *)
  type 'a t = {
    index: int;
    total: int;
    next: 'a list; [@default []]
    previous: 'a list; [@default []]
  }
  [@@deriving yojson, fields]
end

module Make_search_context_result (X : Type) = struct
  type t = X.t Search_context_result.t
  [@@deriving yojson]
end

(** {2 Queries} *)

module Query_parser = struct
  exception Parse_error of string
  let parse_errorf fmt = Format.kasprintf (fun msg -> raise (Parse_error msg)) fmt

  type operators = string list String.Map.t

  type split = {
    terms: string;
    operators: operators;
  }

  let split query : split =
    let components = String.split_on_char ' ' query in
    let (terms, operators) =
      List.partition_map
        (fun component ->
          match String.split_on_char ':' component with
          | [] -> assert false
          | [term] -> Left term
          | [operator; arguments] -> Right (operator, String.split_on_char ',' arguments)
          | _ -> parse_errorf "the component %S contains more than one column character (':')" component
        )
        components
    in
    let terms = String.concat " " @@ List.filter ((<>) "") terms in
    let operators =
      List.fold_left
        (fun map (operator, arguments) ->
          if String.Map.mem operator map then
            parse_errorf "the operator %S is used several times" operator
          else
            String.Map.add operator arguments map
        )
        String.Map.empty
        operators
    in
      {terms; operators}

  type parse_operator = {
    parse_operator: 'result. string -> (string list -> 'result) -> 'result option;
  }

  let make parse_operators query =
    try
      let {terms; operators} = split query in
      let remaining_operators = ref operators in
      let parse_operator = {
        parse_operator = fun op f ->
          match String.Map.find_opt op !remaining_operators with
          | None -> None
          | Some arguments ->
            remaining_operators := String.Map.remove op !remaining_operators;
            Some (f arguments)
      }
      in
      let result = parse_operators terms parse_operator in
      match String.Map.choose_opt !remaining_operators with
      | Some (operator, _arguments) -> parse_errorf "unexpected operator %S" operator
      | None -> Ok result
    with
      | Parse_error msg -> Error msg
      | exn -> Error (spf "unexpected exception while parsing: %s" @@ Printexc.to_string exn)
end

module Query_printer = struct
  type operators = (string * string list) list

  type print_operator = {
    print_operator: 'x. string -> ('x -> string list) -> 'x option -> unit;
  }

  let make print_operators query =
    let operators : operators ref = ref [] in
    let print_operator = {
      print_operator = fun op f xo ->
        Option.iter
          (fun x ->
            operators := (op, f x) :: !operators
          )
          xo
    }
    in
    let terms = print_operators print_operator query in
    let components = List.map (fun (op, vs) -> op ^ ":" ^ String.concat "," vs) (List.rev !operators) in
    let components = components @ (if terms = "" then [] else [terms]) in
    String.concat " " components
end

module Query = struct
  type common = {
    terms: string; [@default ""]
  }
  [@@deriving make, yojson]

  type 'a t = {
    common: common; [@default make_common ()]
    specific: 'a;
  }
  [@@deriving make, yojson]

  let make_parser f =
    Query_parser.make @@ fun terms {parse_operator} ->
    let specific = f {Query_parser.parse_operator} in
      {common = {terms}; specific}

  let make_printer f =
    Query_printer.make @@ fun {print_operator} query ->
    let {common = {terms}; specific} = query in
    f {Query_printer.print_operator} specific;
    terms
end

module Person_query = struct
  type specific = unit
  [@@deriving yojson]

  let make_specific () = ()

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    ignore parse_operator

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} () ->
    ignore print_operator

  let print = Query.make_printer print_operators
end

module User_query = struct
  type specific = unit
  [@@deriving yojson]

  let make_specific () = ()

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    ignore parse_operator

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} () ->
    ignore print_operator

  let print = Query.make_printer print_operators
end

module Dance_query = struct
  type specific = {
    deviser: Person_id.t list option; [@default None]
  }
  [@@deriving make, yojson]

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    let deviser = parse_operator "deviser" (List.map Entry.Id.of_string_exn) in
      {deviser}

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} query ->
    let {deviser} = query in
    print_operator "deviser" (List.map Entry.Id.to_string) deviser

  let print = Query.make_printer print_operators
end

module Source_query = struct
  type specific = {
    editor: Person_id.t list option; [@default None]
  }
  [@@deriving make, yojson]

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    let editor = parse_operator "editor" (List.map Entry.Id.of_string_exn) in
      {editor}

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} query ->
    let {editor} = query in
    print_operator "editor" (List.map Entry.Id.to_string) editor

  let print = Query.make_printer print_operators
end

module Tune_query = struct
  type specific = {
    kind: Kind_base.t list option; [@default None]
    composer: Person_id.t list option; [@default None]
  }
  [@@deriving make, yojson]

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    let kind = parse_operator "kind" (List.map Kind_base.of_string) in
    let composer = parse_operator "composer" (List.map Entry.Id.of_string_exn) in
      {kind; composer}

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} query ->
    let {kind; composer} = query in
    print_operator "kind" (List.map (Kind_base.to_long_string ~capitalised: false)) kind;
    print_operator "composer" (List.map Entry.Id.to_string) composer

  let print = Query.make_printer print_operators
end

module Version_query = struct
  type specific = {
    tune: Tune_query.specific; [@default Tune_query.make_specific ()]
    key: Music.Key.t list option; [@default None]
    source: Source_id.t list option; [@default None]
  }
  [@@deriving make, yojson]

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    let tune = Tune_query.parse_operators {parse_operator} in
    let key = parse_operator "key" (List.map Music.Key.of_string) in
    let source = parse_operator "source" (List.map Entry.Id.of_string_exn) in
      {tune; key; source}

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} query ->
    let {tune; key; source} = query in
    Tune_query.print_operators {print_operator} tune;
    print_operator "key" (List.map Music.Key.to_string) key;
    print_operator "source" (List.map Entry.Id.to_string) source

  let print = Query.make_printer print_operators
end

module Set_query = struct
  type specific = {
    conceptor: Person_id.t list option; [@default None]
    contains_version: Version_id.t list option; [@default None]
    contains_tune: Tune_id.t list option; [@default None]
  }
  [@@deriving make, yojson]

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    let conceptor = parse_operator "conceptor" (List.map Entry.Id.of_string_exn) in
    let contains_version = parse_operator "contains-version" (List.map Entry.Id.of_string_exn) in
    let contains_tune = parse_operator "contains-tune" (List.map Entry.Id.of_string_exn) in
      {conceptor; contains_version; contains_tune}

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} query ->
    let {conceptor; contains_version; contains_tune} = query in
    print_operator "conceptor" (List.map Entry.Id.to_string) conceptor;
    print_operator "contains-version" (List.map Entry.Id.to_string) contains_version;
    print_operator "contains-tune" (List.map Entry.Id.to_string) contains_tune

  let print = Query.make_printer print_operators
end

module Book_query = struct
  type specific = {
    author: Person_id.t list option; [@default None]
    contains_version: Version_id.t list option; [@default None]
    contains_tune: Tune_id.t list option; [@default None]
    contains_set: Set_id.t list option; [@default None]
  }
  [@@deriving make, yojson]

  type t = specific Query.t
  [@@deriving yojson]

  let parse_operators = fun {Query_parser.parse_operator} ->
    let author = parse_operator "author" (List.map Entry.Id.of_string_exn) in
    let contains_version = parse_operator "contains-version" (List.map Entry.Id.of_string_exn) in
    let contains_tune = parse_operator "contains-tune" (List.map Entry.Id.of_string_exn) in
    let contains_set = parse_operator "contains-set" (List.map Entry.Id.of_string_exn) in
      {author; contains_version; contains_tune; contains_set}

  let parse = Query.make_parser parse_operators

  let print_operators = fun {Query_printer.print_operator} query ->
    let {author; contains_version; contains_tune; contains_set} = query in
    print_operator "author" (List.map Entry.Id.to_string) author;
    print_operator "contains-version" (List.map Entry.Id.to_string) contains_version;
    print_operator "contains-tune" (List.map Entry.Id.to_string) contains_tune;
    print_operator "contains-set" (List.map Entry.Id.to_string) contains_set

  let print = Query.make_printer print_operators
end

module Any_query = struct
  type model_specific =
    | Person of Person_query.specific
    | User of User_query.specific
    | Dance of Dance_query.specific
    | Source of Source_query.specific
    | Tune of Tune_query.specific
    | Version of Version_query.specific
    | Set of Set_query.specific
    | Book of Book_query.specific
  [@@deriving yojson, variants]

  type specific = model_specific option
  [@@deriving yojson]

  type t = specific Query.t
  [@@deriving yojson]

  let empty : t = {common = {terms = ""}; specific = None}
  let specific_only specific = {empty with specific = Some specific}

  let parse : string -> (t, string) result =
    Query.make_parser @@ fun {parse_operator} ->
    match parse_operator "type" (List.map String.lowercase_ascii) with
    | None -> None
    | Some type_ ->
      some @@
        match type_ with
        | ["person"] -> Person (Person_query.parse_operators {parse_operator})
        | ["user"] -> User (User_query.parse_operators {parse_operator})
        | ["dance"] -> Dance (Dance_query.parse_operators {parse_operator})
        | ["source"] -> Source (Source_query.parse_operators {parse_operator})
        | ["tune"] -> Tune (Tune_query.parse_operators {parse_operator})
        | ["version"] -> Version (Version_query.parse_operators {parse_operator})
        | ["set"] -> Set (Set_query.parse_operators {parse_operator})
        | ["book"] -> Book (Book_query.parse_operators {parse_operator})
        | _ -> Query_parser.parse_errorf "unexpected type %S" (String.concat "," type_)

  let print : t -> string =
    Query.make_printer @@ fun {print_operator} query ->
    match query with
    | None -> ()
    | Some Person query -> print_operator "type" Fun.id (Some ["person"]); Person_query.print_operators {print_operator} query
    | Some User query -> print_operator "type" Fun.id (Some ["user"]); User_query.print_operators {print_operator} query
    | Some Dance query -> print_operator "type" Fun.id (Some ["dance"]); Dance_query.print_operators {print_operator} query
    | Some Source query -> print_operator "type" Fun.id (Some ["source"]); Source_query.print_operators {print_operator} query
    | Some Tune query -> print_operator "type" Fun.id (Some ["tune"]); Tune_query.print_operators {print_operator} query
    | Some Version query -> print_operator "type" Fun.id (Some ["version"]); Version_query.print_operators {print_operator} query
    | Some Set query -> print_operator "type" Fun.id (Some ["set"]); Set_query.print_operators {print_operator} query
    | Some Book query -> print_operator "type" Fun.id (Some ["book"]); Book_query.print_operators {print_operator} query
end
