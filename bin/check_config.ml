open Dancelor_server

let () =
  Lwt_main.run @@
    let%lwt _ : Config.t = Config.read_from_file Sys.argv.(1) in
    exit 0
