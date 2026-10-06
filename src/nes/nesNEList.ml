type 'a t = (::) of 'a * 'a list [@@deriving eq, ord]

let to_list : 'a t -> 'a list = fun (x :: xs) -> x :: xs

let of_list : 'a list -> 'a t option = function
  | [] -> None
  | x :: xs -> Some (x :: xs)

let of_list_exn : 'a list -> 'a t = function
  | [] -> invalid_arg "NEList.of_list_exn"
  | x :: xs -> x :: xs

let cons x xs = x :: xs

type 'a mylist = 'a list [@@deriving yojson, show {with_path = false}]

let of_yojson a_of_yojson json =
  Result.bind (mylist_of_yojson a_of_yojson json) @@ fun xs ->
  Option.to_result ~none: "empty list" (of_list xs)

let to_yojson a_to_yojson (x :: xs) =
  mylist_to_yojson a_to_yojson (x :: xs)

let map f (x :: xs) = f x :: List.map f xs
let map_lwt_p f (x :: xs) =
  let%lwt y = f x in
  let%lwt ys = Lwt_list.map_p f xs in
  Lwt.return (y :: ys)

let hd (x :: _) = x
let tl (_ :: xs) = xs

let singleton x = x :: []

let is_singleton (_ :: xs) = List.is_empty xs

let mem n (x :: xs) = n = x || List.mem n xs
let exists f (x :: xs) = f x || List.exists f xs

let show pp_x (x :: xs) = show_mylist pp_x (x :: xs)
let pp pp_x fmt (x :: xs) = pp_mylist pp_x fmt (x :: xs)
