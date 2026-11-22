let namespace = "dancelor"

let http_requests_total =
  Prometheus.Counter.v
    ~namespace
    ~help: "Total number of HTTP requests"
    "http_requests_total"

let increment_http_requests_total () = Prometheus.Counter.inc_one http_requests_total

let http_requests_count =
  let family =
    Prometheus.Counter.v_labels
      ~namespace
      ~help: "Number of HTTP requests"
      "http_requests_count"
      ~label_names: ["kind"; "file"]
  in
  fun ~kind ~file ->
    Prometheus.Counter.labels family [kind; file]

let increment_http_requests_count = function
  | `API -> Prometheus.Counter.inc_one (http_requests_count ~kind: "API" ~file: "")
  | `Main_file -> Prometheus.Counter.inc_one (http_requests_count ~kind: "Main file" ~file: "")
  | `Static file -> Prometheus.Counter.inc_one (http_requests_count ~kind: "Static" ~file)

let open_file_descriptors =
  Prometheus.Gauge.v
    ~namespace
    ~help: "Number of open file descriptors"
    "open_file_descriptors"

let () =
  Prometheus.CollectorRegistry.(register_pre_collect default) (fun () ->
    Prometheus.Gauge.set open_file_descriptors @@
      float_of_int (try Array.length (Sys.readdir "/proc/self/fd") with Sys_error _ -> 0)
  )
