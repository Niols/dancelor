open Nes
open React

let now () = Unix.gettimeofday ()

let now_s =
  let (now_s, set_now) = S.create (now ()) in
  let rec run () =
    set_now (now ());
    Js_of_ocaml_lwt.Lwt_js.sleep 1.;%lwt
    run ()
  in
  Lwt.async run;
  now_s

let duration_human seconds =
  if seconds <= 0 then
    "now"
  else if seconds = 1 then
    "one second"
  else if seconds < 60 then
    spf "%d seconds" seconds
  else
    let seconds = seconds / 60 in
    if seconds = 1 then
      "one minute"
    else if seconds < 60 then
      spf "%d minutes" seconds
    else
      let seconds = seconds / 60 in
      if seconds = 1 then
        "one hour"
      else if seconds < 24 then
        spf "%d hours" seconds
      else
        let seconds = seconds / 24 in
        if seconds = 1 then
          "one day"
        else
          spf "%d days" seconds

let diff_seconds a b = int_of_float @@ ceil @@ a -. b

let ago_s then_ =
  S.map (fun now_ -> duration_human (diff_seconds now_ then_) ^ " ago") now_s
