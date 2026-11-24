type 'v entry = {
  value: 'v;
  created_at: NesDatetime.t;
}

let entry_age ~now entry = NesDatetime.diff now entry.created_at

type ('k, 'v) t = {
  entries: ('k, 'v entry) Hashtbl.t;
  entry_lifetime: NesDatetime.duration;
  cleanup_every: NesDatetime.duration;
  mutable last_cleanup: NesDatetime.t;
}

let create ?(lifetime = NesDatetime.forever) () = {
  entries = Hashtbl.create 8;
  entry_lifetime = lifetime;
  cleanup_every = lifetime;
  last_cleanup = NesDatetime.now ();
}

let cleanup ~cache =
  let now = NesDatetime.now () in
  Hashtbl.filter_map_inplace
    (fun _ entry ->
      if NesDatetime.compare_duration (entry_age ~now entry) cache.entry_lifetime > 0 then None
      else Some entry
    )
    cache.entries;
  cache.last_cleanup <- now

let cleanup_if_due ~cache ~now =
  if NesDatetime.compare_duration (NesDatetime.diff now cache.last_cleanup) cache.cleanup_every > 0 then
    cleanup ~cache

let get' ~cache ~key ~now =
  cleanup_if_due ~cache ~now;
  match Hashtbl.find_opt cache.entries key with
  | Some entry when NesDatetime.compare_duration (entry_age ~now entry) cache.entry_lifetime <= 0 ->
    Some entry.value
  | _ -> None

let set' ~cache ~key ~value ~now =
  Hashtbl.replace cache.entries key {value; created_at = now}

let use ~cache ~key ?(if_ = true) thunk =
  let now = NesDatetime.now () in
  if if_ then
    match get' ~cache ~key ~now with
    | Some value -> value
    | _ ->
      let value = thunk () in
      set' ~cache ~key ~value ~now;
      value
  else
    thunk ()

let get ~cache ~key =
  get' ~cache ~key ~now: (NesDatetime.now ())

let set ~cache ~key ~value =
  set' ~cache ~key ~value ~now: (NesDatetime.now ())

let size ~cache = Hashtbl.length cache.entries
