module Entry_sql = Entry_sql.Sqlgg(Sqlgg_postgresql)

let get_type ~actor_id id =
  Connection.with_ @@ fun db ->
  Entry_sql.Single.get_type db ~actor_id ~id (fun ~type_ -> type_)

let get_newest = Entry.get_newest
