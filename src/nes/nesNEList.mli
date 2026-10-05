(** {1 Non-empty list} *)

type 'a t =
  (::) of 'a * 'a list
[@@deriving eq, ord, show, yojson]
(** A non-empty list. We overload the [(::)] constructor so code with non-empty
    lists looks natural, pattern-matching and all. *)

val to_list : 'a t -> 'a list
(** Convert a non-empty list to a regular list. *)

val of_list : 'a list -> 'a t option
(** Convert a list to a non-empty list. *)

val of_list_exn : 'a list -> 'a t
(** Convert a list to a non-empty string, or raise {!Invalid_argument} if the
    list is empty. *)

val cons : 'a -> 'a list -> 'a t
(** Add an element in front of a list and recover a non-empty list. *)

val hd : 'a t -> 'a
(** Get the head of a non-empty list, that is the first element of the list. *)

val tl : 'a t -> 'a list
(** Get the tail of a non-empty list, that is the list without its first
    element. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** Map a function over a non-empty list. *)

val map_lwt_p : ('a -> 'b Lwt.t) -> 'a t -> 'b t Lwt.t
(** Similar to {!Lwt_list.map_p} for non-empty lists. *)

val singleton : 'a -> 'a t
(** Create a non-empty list with a single element. *)

val is_singleton : 'a t -> bool
(** Check if the non-empty list contains a single element. *)

val mem : 'a -> 'a t -> bool
val exists : ('a -> bool) -> 'a t -> bool
