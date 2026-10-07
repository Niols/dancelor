open Js_of_ocaml
open Nes
open Dancelor_common

module Log = (val Logs.src_log @@ Logs.Src.create "client.history": Logs.LOG)

let madge_call_or_option endpoint id =
  Lwt.flip_map (Api.call endpoint id) @@ function
    | Ok v -> Some v
    | Error (Madge_client.Http {status = `Not_found; _}) -> None
    | Error e -> raise (Madge_client.Error e)

type history = (Datetime.t * Uri.t) list [@@deriving yojson]

let empty_history : history = []

(** Maximal size of the history. *)
let limit = 1000

let with_local_storage ~default f =
  Option.fold ~none: default ~some: f @@ Js.Optdef.to_option Dom_html.window##.localStorage

let get () =
  with_local_storage ~default: empty_history @@ fun local_storage ->
  match Js.Opt.to_option @@ local_storage##getItem (Js.string "history") with
  | None -> empty_history
  | Some history ->
    match history_of_yojson @@ Yojson.Safe.from_string @@ Js.to_string history with
    | Error _ -> empty_history
    | Ok history -> history

let set history =
  with_local_storage ~default: () @@ fun local_storage ->
  local_storage##setItem (Js.string "history") (Js.string @@ Yojson.Safe.to_string @@ history_to_yojson history)

let update f = set @@ f @@ get ()

let add (uri : Uri.t) : unit =
  update (fun history -> (Datetime.now (), uri) :: List.take (limit - 1) history)

(** Returns all the resources whose page is present in the history. *)
let get_resource_ids () : Resource_id.t list =
  let resource_id : type a r. (a, Resource_id.t option, r) Endpoints.Page.t -> a = function
    | Person View -> (fun _ -> some % Resource_id.person)
    | Dance View -> (fun _ -> some % Resource_id.dance)
    | Source View -> (fun _ -> some % Resource_id.source)
    | Tune View -> (fun _ -> some % Resource_id.tune)
    | Version View -> (fun _ _ -> some % Resource_id.version)
    | Set View -> (fun _ -> some % Resource_id.set)
    | Book View -> (fun _ -> some % Resource_id.book)
    (* everything else we ignore *)
    | endpoint -> Endpoints.Page.consume endpoint ~return: None
  in
  let resource_id uri : Resource_id.t option =
    Option.join @@
    Option.map (fun f -> f ()) @@
    List.find_map
      (fun (Endpoints.Page.W' endpoint) ->
        Madge.apply'
          (Endpoints.Page.route endpoint)
          (fun () -> resource_id endpoint)
          (Madge.Request.make ~meth: GET ~uri ~body: "")
      )
      (Endpoints.Page.all' ())
  in
  let resource_ids = List.filter_map (resource_id % snd) (get ()) in
  List.deduplicate ~eq: (Resource_id.equal) resource_ids

let get_resources () : Resource_row.t list Lwt.t =
  Logger.bracket (module Log) "getting entities" @@ fun () ->
  Api.call_exn (Entity Resource_rows) (get_resource_ids ())

(** Returns all the sets whose page is present in the history. *)
let get_sets () : Set_row.t list Lwt.t =
  Logger.bracket_lwt (module Log) "getting sets" @@ fun () ->
  let set_ids = List.filter_map (function `Set set -> Some set | _ -> None) (get_resource_ids ()) in
  Api.call_exn (Set Get_rows) set_ids

(** Returns all the books whose page is present in the history. *)
let get_books () : Book_row.t list Lwt.t =
  Logger.bracket_lwt (module Log) "getting books" @@ fun () ->
  let book_ids = List.filter_map (function `Book book -> Some book | _ -> None) (get_resource_ids ()) in
  Api.call_exn (Book Get_rows) book_ids
