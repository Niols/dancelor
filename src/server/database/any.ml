open Dancelor_common

module Entry_sql = Entry_sql.Sqlgg(Sqlgg_postgresql)

let get_type ~actor_id id =
  let id = Id.unsafe_coerce id in
  Connection.with_ @@ fun db ->
  Entry_sql.Single.get_type db ~actor_id ~id (fun ~type_ -> Sql_types.type_to_common type_)

let get_newest = Entry_new.get_newest
