open Nes
open Dancelor_common
open Model_new

let person_sql_to_row ~id ~name ~(k : Person_row.t -> 'w) : 'w =
  k {id; name}

let person_sql_to_tune_composer ~id ~name ~details ~(k : Tune_form.composer -> 'w) : 'w =
  k {
    composer = {id; name};
    details = Option.map NEString.of_string_exn details;
  }

let source_sql_to_row ~id ~name ~date ~editors ~(k : Source_row.t -> 'w) : 'w =
  k {id; name; date = Option.map (Option.get % PartialDate.from_string) date; editors}

let dance_sql_to_row ~id ~name ~kind ~devisers ~disambiguation ~(k : Dance_row.t -> 'w) : 'w =
  k {
    id;
    name;
    kind = Kind_dance.of_string kind;
    devisers;
    disambiguation;
  }

let tune_sql_to_row ~id ~name ~kind ~composers ~(k : Tune_row.t -> 'w) : 'w =
  k {
    id;
    name;
    kind = Sql_types.kind_base_to_common kind;
    composers;
  }

let version_sql_to_row
    ~id
    ~sources
    ~arrangers
    ~tune_composers
    ~disambiguation
    ~monolithic_bars
    ~monolithic_or_default_structure
    ~tune_id
    ~tune_name
    ~tune_kind
    ~(k : Version_row.t -> 'w)
    : 'w
  =
  let content : Version_row.content =
    match (monolithic_bars, monolithic_or_default_structure) with
    | (None, None) -> No_content
    | (None, Some _default_structure) -> Destructured
    | (Some bars, Some structure) ->
      Monolithic {
        bars = Int64.to_int bars;
        structure = Option.get (Model_builder.Core.Version.Structure.of_string (NEString.of_string_exn structure));
      }
    | _ -> assert false
  in
  k {
    id;
    tune = tune_sql_to_row ~id: tune_id ~name: tune_name ~kind: tune_kind ~composers: tune_composers ~k: Fun.id;
    sources;
    disambiguation;
    arrangers;
    content;
  }

let set_sql_to_row
    ~id
    ~entry_is_public
    ~actor_role
    ~actor_is_omniscient_administrator
    ~name
    ~kind
    ~conceptors
    ~tunes
    ~(k : Set_row.t -> 'w)
    : 'w
  =
  k {
    id;
    name;
    kind = Kind_dance.of_string kind;
    conceptors;
    tunes;
    permission = {
      entry_is_public;
      actor_role = Option.map Sql_types.actor_role_to_common actor_role;
      actor_is_omniscient_administrator;
    };
  }

let book_sql_to_row
    ~id
    ~entry_is_public
    ~actor_role
    ~actor_is_omniscient_administrator
    ~name
    ~date
    ~authors
    ~(k : Book_row.t -> 'w)
    : 'w
  =
  k {
    id;
    name;
    date = Option.map (Option.get % PartialDate.from_string) date;
    authors;
    permission = {
      entry_is_public;
      actor_role = Option.map Sql_types.actor_role_to_common actor_role;
      actor_is_omniscient_administrator;
    };
  }

let user_sql_to_row
    ~id
    ~username
    ~(k : User_row.t -> 'w)
    : 'w
  =
  k {
    id;
    username = Username.of_string_exn username;
  }
