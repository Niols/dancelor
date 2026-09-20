(** {1 Cache} *)

type ('key, 'value) t
(** Type of a cache binding ['key]s to ['value]s. *)

val create : ?lifetime: int -> unit -> ('key, 'value) t
(** Create a cache. The [?lifetime] argument allows to specify (in seconds) when
    bindings from the cache should be invalidated. Entries are _actually_
    removed from the cache during normal {!use} or when explicitly calling for a
    {!cleanup}. *)

val use :
  cache: ('key, 'value) t ->
  key: 'key ->
  ?if_: bool ->
  (unit -> 'value) ->
  'value
(** Looks up the [~key] in the [~cache]. If it exists, return its value.
    Otherwise, call the given function, store its result and return it. The
    optional argument, [?if_], skips the cache when [false] ([true] by default). *)

val get :
  cache: ('key, 'value) t ->
  key: 'key ->
  'value option
(** Looks up the [~key] in the [~cache] and return its value. *)

val set :
  cache: ('key, 'value) t ->
  key: 'key ->
  value: 'value ->
  unit
(** Adds or replaces the [~value] associated to [~key] in the [~cache]. *)

val cleanup :
  cache: ('key, 'value) t ->
  unit
(** Remove from the cache any value that is past its lifetime. Regular cleanup
    also happens automatically on normal use. *)
