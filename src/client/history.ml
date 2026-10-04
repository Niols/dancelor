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

(** Returns all the models whose page is present in the history. *)
let get_model_ids () : Any_id.t list =
  let model_id : type a r. (a, Any_id.t option, r) Endpoints.Page.t -> a = function
    | Person View -> (fun _ -> some % Any_id.person)
    | Dance View -> (fun _ -> some % Any_id.dance)
    | Source View -> (fun _ -> some % Any_id.source)
    | Tune View -> (fun _ -> some % Any_id.tune)
    | Version View -> (fun _ _ -> some % Any_id.version)
    | Set View -> (fun _ -> some % Any_id.set)
    | Book View -> (fun _ -> some % Any_id.book)
    (* FIXME: user once there is a user viewer page endpoint *)
    (* everything else we ignore *)
    | endpoint -> Endpoints.Page.consume endpoint ~return: None
  in
  let model_id uri : Any_id.t option =
    Option.join @@
    Option.map (fun f -> f ()) @@
    List.find_map
      (fun (Endpoints.Page.W' endpoint) ->
        Madge.apply'
          (Endpoints.Page.route endpoint)
          (fun () -> model_id endpoint)
          (Madge.Request.make ~meth: GET ~uri ~body: "")
      )
      (Endpoints.Page.all' ())
  in
  let model_ids = List.filter_map (model_id % snd) (get ()) in
  List.deduplicate ~eq: (Any_id.equal) model_ids

let get_models () : Any_row.t list Lwt.t =
  Logger.bracket (module Log) "getting models" @@ fun () ->
  Api.call_exn (Any Get_rows) (get_model_ids ())

(** Returns all the sets whose page is present in the history. *)
let get_sets () : Set_row.t list Lwt.t =
  Logger.bracket_lwt (module Log) "getting sets" @@ fun () ->
  let set_ids = List.filter_map (function Any_id.Set set -> Some set | _ -> None) (get_model_ids ()) in
  Api.call_exn (Set Get_rows) set_ids

(** Returns all the books whose page is present in the history. *)
let get_books () : Book_row.t list Lwt.t =
  Logger.bracket_lwt (module Log) "getting books" @@ fun () ->
  let book_ids = List.filter_map (function Any_id.Book book -> Some book | _ -> None) (get_model_ids ()) in
  Api.call_exn (Book Get_rows) book_ids
