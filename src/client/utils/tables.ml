open Nes
open Html

let make ?header body =
  div
    ~a: [a_class ["table-responsive"; "mx-n2"; "mx-sm-0"]]
    [
      tablex
        ~a: [a_class ["table"; "table-striped"; "table-hover"; "table-borderless"; "my-1"]]
        ?thead: (Option.map (fun header -> thead ~a: [a_class ["table-primary"; "pe-none"]] [tr (List.map (fun str -> th [txt str]) header)]) header)
        ?tfoot: (Option.map (fun header -> tfoot ~a: [a_class ["table-primary"; "pe-none"]] [tr (List.map (fun str -> th [txt str]) header)]) header)
        [body]
    ]

let map_table ?header f list =
  make ?header (tbody (List.map f list))

let dances dances =
  map_table ~header: [""; ""; ""] Any_result.make_dance_result dances

let tunes tunes =
  map_table ~header: [""; ""; ""] Any_result.make_tune_result tunes

let users users =
  map_table ~header: [""; ""; ""] Any_result.make_user_result users

let versions ?onclick versions =
  map_table
    ~header: [""; ""; ""]
    (fun version ->
      Any_result.make_version_result
        ?onclick: (Option.map (fun onclick () -> onclick version) onclick)
        version
    )
    versions

let any ?in_search anys =
  map_table
    ~header: [""; ""; ""; ""; ""]
    (Any_result.make_result ?in_search)
    anys

let placeholder ?(show_thead = true) ?(show_tfoot = true) ?(rows = 3) () = [
  div
    ~a: [a_class ["table-responsive"]]
    [
      tablex
        ~a: [a_class ["table"; "table-striped"; "table-hover"; "table-borderless"; "my-1"]]
        ?thead: (
          if show_thead then
            some @@
              thead
                ~a: [a_class ["table-primary"]]
                [
                  tr [
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                  ];
                ]
          else None
        )
        ?tfoot: (
          if show_tfoot then
            some @@
              tfoot
                ~a: [a_class ["table-primary"]]
                [
                  tr [
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                    th [span_placeholder ()];
                  ];
                ]
          else None
        )
        [
          tbody (
            List.init rows (fun _ ->
              tr [
                td [span_placeholder ()];
                td [span_placeholder ()];
                td [span_placeholder ()];
              ];
            )
          )
        ]
    ]
]
