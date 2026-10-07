open Nes
open Dancelor_common
open Sql_to_name

let person_sql_to_row = person_sql_to_name

let person_sql_to_tune_composer ~id ~name ~details ~(k : Tune_form.composer -> 'w) : 'w =
  k {
    composer = {id; name};
    details = Option.map NEString.of_string_exn details;
  }

let source_sql_to_row ~id ~name ~date ~editors ~(k : Source_row.t -> 'w) : 'w =
  k {id; name; date = Option.map (Option.get % Partial_date.from_string) date; editors}

let dance_sql_to_row ~id ~name ~kind ~devisers ~disambiguation ~(k : Dance_row.t -> 'w) : 'w =
  k {
    id;
    name;
    kind = Kind.Dance.of_string kind;
    devisers;
    disambiguation;
  }

let tune_sql_to_row ~id ~name ~kind ~composers ~(k : Tune_row.t -> 'w) : 'w =
  k {id; name; kind; composers}

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
        structure = Option.get (Version_content.Structure.of_string (NEString.of_string_exn structure));
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

let sql_to_permission
    ~entity_is_public
    ~actor_role
    ~actor_group_id
    ~actor_group_name
    ~actor_is_omniscient_administrator
    : Permission.t
  =
  let actor_role =
    match actor_role, actor_group_id, actor_group_name with
    | None, None, None -> None
    | Some role, None, None -> Some (role, Permission.Direct)
    | Some role, Some id, Some name -> Some (role, Permission.Via_group (group_sql_to_name ~id ~name ~k: Fun.id))
    | _ -> assert false
  in
  {
    entity_is_public;
    actor_role;
    actor_is_omniscient_administrator;
  }

let set_sql_to_row
    ~id
    ~entity_is_public
    ~actor_role
    ~actor_group_id
    ~actor_group_name
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
    kind = Kind.Dance.of_string kind;
    conceptors;
    tunes;
    permission = sql_to_permission ~entity_is_public ~actor_role ~actor_group_id ~actor_group_name ~actor_is_omniscient_administrator;
  }

let book_sql_to_row
    ~id
    ~entity_is_public
    ~actor_role
    ~actor_group_id
    ~actor_group_name
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
    date = Option.map (Option.get % Partial_date.from_string) date;
    authors;
    permission = sql_to_permission ~entity_is_public ~actor_role ~actor_group_id ~actor_group_name ~actor_is_omniscient_administrator;
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

let group_sql_to_row ~id ~name ~(k : Group_row.t -> 'w) : 'w =
  k {id; name}
