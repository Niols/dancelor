(** {1 Madge's endpoints wrapper}

    Madge features GADT-style endpoints that carry extra type information. This
    makes it hard to manipulate lists of endpoints. However, it is frequent to
    want to iterate over all endpoints to find one that might be matching, for
    instance. The solution for this purpose is to use another GADT to hide the
    type information. Typically, one would do:
    {|
      type wrapped = W : ('a, 'w, 'r) endpoint -> wrapped
    |}
    or, in fact, more useful:
    {|
      type wrapped = W : ('a, 'r Lwt.t, 'r) endpoint -> wrapped
    |}

    One can then put values of type [wrapped] in the same list without issue.
    When matching on [W] and getting the value it wraps, the type equalities
    will still be there, happily waiting, and we will be able to use the
    endpoint in question.

    This PPX automatises the definition of this type, and, more importantly, the
    definition of a value, [all], containing all the endpoints of the given
    type, wrapped. The usage is as follows:
    {|
      type ('a, 'w, 'r) sub_endpoint =
        | Foo : ((string -> 'w), 'w, int) sub_endpoint
      [@@deriving madge_wrapped_endpoints]

      type ('a, 'w, 'r) t =
        | Bar : ((float -> 'w), 'w, bool) t
        | Lift : ('a, 'w, 'r) sub_endpont -> ('a, 'w, 'r) t
      [@@deriving madge_wrapped_endpoints]
    |}

    This will generate, among other things:
    {|
      type wrapped_sub_endpoint = W_sub_endpoint : ('a, 'r Lwt.t, 'r) sub_endpoint -> wrapped_sub_endpoint
      let all_sub_endpoints : wrapped_sub_endpoint list = [W_sub_endpoint Foo]

      type wrapped = W : ('a, 'r Lwt.t, 'r) t -> wrapped
      let all : wrapped list = List.flatten [
        [W Bar];
        List.map (fun (W_sub_endpoint e) -> W (Lift e)) all_sub_endpoints;
      ]
    |}
    allowing to iterate on [all] endpoints easily.

    Sometimes, however, one wants to match on all endpoints, but not with the
    goal of applying the corresponding constructors. For this reason, this PPX
    also produces:
    {|
      type 'w wrapped_endpoint' =
        W_endpoint' : ('a, 'w, 'r) endpoint -> 'w wrapped_endpoint'

      val all_endpoints' : unit -> 'w wrapped_endpoint' list
    |}

    In such a wrapping, the return type is lost, but it is possible to inject
    any type of one's choosing. The [unit ->] type is to avoid type issues where
    ['w] cannot be generalised.

    As a bonus, this PPX also generates a value
    {|
      val endpoint_name : 'a 'w 'r. ('a, 'w, 'r) endpoint -> string
    |}
    giving a string representation of the endpoint's name. In the example above,
    we would have [name (Lift Foo) = "Lift Foo"]. *)

open Ppxlib
open Ast_builder.Default

let loc_lident ~loc txt = Loc.make ~loc @@ Longident.parse txt

let map_lident_last f = function
  | Lident x -> Lident (f x)
  | Ldot (li, x) -> Ldot (li, f x)
  | _ -> assert false

let pexp_unit ~loc = pexp_construct ~loc (loc_lident ~loc "()") None
let ppat_unit ~loc = ppat_construct ~loc (loc_lident ~loc "()") None

let wrapped_name ~quot typ =
  (match typ with "t" -> "wrapped" | _ -> "wrapped_" ^ typ) ^
    (if quot then "'" else "")

let w_name ~quot typ =
  (match typ with "t" -> "W" | _ -> "W_" ^ typ) ^
    (if quot then "'" else "")

let all_names ~quot typ =
  (match typ with "t" -> "all" | _ -> "all_" ^ typ ^ "s") ^
    (if quot then "'" else "")

let name_name = function
  | "t" -> "name"
  | typ -> typ ^ "_name"

let match_args_name = function
  | "t" -> "match_args"
  | typ -> "match_" ^ typ ^ "s_args"

let match_name = function
  | "t" -> "match_"
  | typ -> "match_" ^ typ ^ "s"

(** Generates one of:
    {|
      type wrapped_<name> = W_<name> : ('a, 'r Lwt.t, 'r) <name> -> wrapped_<name>
    |}
    or
    {|
      type 'w wrapped_<name>' = W_<name>' : ('a, 'w, 'r) <name> -> 'w wrapped_<name>'
    |}
    depending on the [~quot] argument.
 *)
let generate_type_wrapped ~quot ~loc name =
  pstr_type ~loc Recursive [
    type_declaration
      ~loc
      ~name: (Loc.make ~loc @@ wrapped_name ~quot name)
      ~params: (if quot then [(ptyp_var ~loc "w", (NoVariance, NoInjectivity))] else [])
      ~cstrs: []
      ~kind: (
        (* W_<name> : ('a, 'r Lwt.t, 'r) <name> -> wrapped_<name> *)
        (* W_<name>' : ('a, 'w, 'r) <name> -> 'w wrapped_<name>' *)
        Ptype_variant [
          constructor_declaration
            ~loc
            ~name: (Loc.make ~loc @@ w_name ~quot name)
            ~args: (
              Pcstr_tuple [
                (* ('a, 'r Lwt.t, 'r) <name> *)
                (* ('a, 'w, 'r) <name> *)
                ptyp_constr
                  ~loc
                  (Loc.make ~loc @@ Lident name)
                  [
                    ptyp_var ~loc "a";
                    (
                      if quot then
                        ptyp_var ~loc "w"
                      else
                        ptyp_constr ~loc (loc_lident ~loc "Lwt.t") [ptyp_var ~loc "r"]
                    );
                    ptyp_var ~loc "r";
                  ]
              ]
            )
            ~res: (
              Some (
                (* wrapped_<name> *)
                (* 'w wrapped_<name>' *)
                ptyp_constr
                  ~loc
                  (loc_lident ~loc @@ wrapped_name ~quot name)
                  (if quot then [ptyp_var ~loc "w"] else [])
              )
            )
        ]
      )
      ~private_: Public
      ~manifest: None
  ]

(** Generates one of
    {|
      let all_<name>s : wrapped list =
        List.flatten
          [
            [W_<name> <Cstr1>];
            List.map (fun (W_<name2> endpoint) -> W_<name> (<Cstr2> endpoint)) all_<name2>s;
          ]
    |}
    or
    {|
      let all_<name>s' : unit -> 'w wrapped' list =
        fun () ->
          List.flatten
            [
              [W_<name>' <cstr1>];
              List.map (fun (W_<name2>' endpoint) -> W_<name>' (<Cstr2> endpoint)) all_<name2>s';
            ]
    |}
    depending on the [~quot] argument. <name2> is the name of the type that
    <Cstr2> lifts.
 *)
let generate_all_names ~quot ~loc name cds =
  pstr_value ~loc Nonrecursive [
    value_binding
      ~loc
      ~pat: (
        (* all_<name>s : wrapped list *)
        (* all_<name>s' : unit -> 'w wrapped' list *)
        ppat_constraint
          ~loc
          (ppat_var ~loc @@ Loc.make ~loc @@ all_names ~quot name)
          (
            let wrapped_list =
              ptyp_constr ~loc (loc_lident ~loc "list") [
                ptyp_constr
                  ~loc
                  (loc_lident ~loc @@ wrapped_name ~quot name)
                  (if quot then [ptyp_var ~loc "w"] else []);
              ]
            in
            if quot then
              ptyp_arrow ~loc Nolabel (ptyp_constr ~loc (loc_lident ~loc "unit") []) wrapped_list
            else
              wrapped_list
          )
      )
      ~expr: (
        (* List.flatten ... *)
        (* fun () -> List.flatten ... *)
        let list_flatten_etc =
          pexp_apply
            ~loc
            (pexp_ident ~loc @@ loc_lident ~loc "List.flatten")
            [
              Nolabel,
              (* [ ... ] *)
              elist ~loc (
                List.map
                  (fun cd ->
                    match cd.pcd_args with
                    | Pcstr_tuple [] ->
                      (* [W_<name> <Cstr1>] *)
                      (* [W_<name>' <Cstr1>] *)
                      elist ~loc [
                        pexp_construct
                          ~loc
                          (loc_lident ~loc @@ w_name ~quot name)
                          (Some (pexp_construct ~loc (loc_lident ~loc cd.pcd_name.txt) None))
                      ]
                    | Pcstr_tuple [{ptyp_desc = Ptyp_constr ({txt = long_name2; _}, _); _}] ->
                      (* List.map (fun (W_<name2> endpoint) -> W_<name> (<Cstr2> endpoint)) all_<name2>s; *)
                      (* List.map (fun (W_<name2> endpoint) -> W_<name>' (<Cstr2> endpoint)) all_<name2>s; *)
                      pexp_apply
                        ~loc
                        (pexp_ident ~loc @@ loc_lident ~loc "List.map")
                        [
                          (
                            Nolabel,
                            (* fun (W_<name2> endpoint) -> W_<name> (<Cstr2> endpoint) *)
                            (* fun (W_<name2>' endpoint) -> W_<name>' (<Cstr2> endpoint) *)
                            pexp_fun
                              ~loc
                              Nolabel
                              None
                              (
                                (* (W_<name2> endpoint) *)
                                ppat_construct
                                  ~loc
                                  (Loc.make ~loc @@ map_lident_last (w_name ~quot) long_name2)
                                  (Option.some @@ ppat_var ~loc @@ Loc.make ~loc "endpoint")
                              )
                              (
                                (* W_<name> (<Cstr2> endpoint) *)
                                (* W_<name>' (<Cstr2> endpoint) *)
                                pexp_construct
                                  ~loc
                                  (loc_lident ~loc @@ w_name ~quot name)
                                  (
                                    Option.some @@
                                      pexp_construct
                                        ~loc
                                        (loc_lident ~loc cd.pcd_name.txt)
                                        (Option.some @@ pexp_ident ~loc @@ loc_lident ~loc "endpoint")
                                  )
                              )
                          );
                          (
                            Nolabel,
                            (* all_<name2>s *)
                            (* all_<name2>s' () *)
                            let all_names2 =
                              pexp_ident ~loc @@ Loc.make ~loc @@ map_lident_last (all_names ~quot) long_name2
                            in
                            if quot then pexp_apply ~loc all_names2 [Nolabel, pexp_unit ~loc]
                            else all_names2
                          );
                        ]
                    | _ ->
                      Location.raise_errorf
                        ~loc: cd.pcd_loc
                        "ppx_madge_wrapped_endpoints: constructor with arguments not supported"
                  )
                  cds
              )
            ]
        in
        if quot then
          pexp_fun ~loc Nolabel None (ppat_unit ~loc) list_flatten_etc
        else
          list_flatten_etc
      )
  ]

(** Generates
    {|
      let <name>_name (type a) (type w) (type r) (endpoint : (a, w, r) <name>) =
        ((match endpoint with
          | <Cstr1> -> "<Cstr1>"
          | <Cstr2> endpoint -> "<Cstr2> " ^ <name2>_name endpoint)
         : string)
    |}
    because generating the following was too complicated with the AST of 5.0.0:
    {|
      let <name>_name : type a w r. (a, w, r) <name> -> string = function
        | <Cstr1> -> "<Cstr1>"
        | <Cstr2> endpoint -> "<Cstr2> " ^ <name2>_name endpoint
    |}
*)
let generate_name_function ~loc name cds =
  pstr_value ~loc Nonrecursive [
    value_binding
      ~loc
      ~pat: (ppat_var ~loc @@ Loc.make ~loc @@ name_name name)
      ~expr: (
        (* (type a) (type w) (type r) ... *)
        pexp_newtype ~loc (Loc.make ~loc "a") @@
        pexp_newtype ~loc (Loc.make ~loc "w") @@
        pexp_newtype ~loc (Loc.make ~loc "r") @@
        (* (endpoint : (a, w, r) <name>) ... *)
        pexp_fun ~loc Nolabel None (
          ppat_constraint
            ~loc
            (ppat_var ~loc @@ Loc.make ~loc "endpoint")
            (
              ptyp_constr ~loc (loc_lident ~loc name) [
                ptyp_constr ~loc (loc_lident ~loc "a") [];
                ptyp_constr ~loc (loc_lident ~loc "w") [];
                ptyp_constr ~loc (loc_lident ~loc "r") [];
              ]
            )
        ) @@
        (* (... : string) *)
        pexp_constraint
          ~loc
          (
            (* match endpoint with ... *)
            pexp_match ~loc (pexp_ident ~loc @@ loc_lident ~loc "endpoint") @@
              List.map
                (fun cd ->
                  match cd.pcd_args with
                  | Pcstr_tuple [] ->
                    (* <Cstr1> -> "<Cstr1>" *)
                    case
                      ~lhs: (ppat_construct ~loc (loc_lident ~loc cd.pcd_name.txt) None)
                      ~guard: None
                      ~rhs: (pexp_constant ~loc @@ Pconst_string (cd.pcd_name.txt, loc, None))
                  | Pcstr_tuple [{ptyp_desc = Ptyp_constr ({txt = long_name2; _}, _); _}] ->
                    (* <Cstr2> endpoint -> "<Cstr2> " ^ <name2>_name endpoint *)
                    case
                      ~lhs: (
                        ppat_construct ~loc (loc_lident ~loc cd.pcd_name.txt) (Some (ppat_var ~loc @@ Loc.make ~loc "endpoint"))
                      )
                      ~guard: None
                      ~rhs: (
                        pexp_apply ~loc (pexp_ident ~loc @@ loc_lident ~loc "(^)") [
                          (Nolabel, pexp_constant ~loc @@ Pconst_string (cd.pcd_name.txt ^ " ", loc, None));
                          (
                            Nolabel,
                            pexp_apply ~loc (pexp_ident ~loc @@ Loc.make ~loc @@ map_lident_last (name_name) long_name2) [
                              (Nolabel, pexp_ident ~loc @@ loc_lident ~loc "endpoint")
                            ]
                          );
                        ]
                      )
                  | _ ->
                    Location.raise_errorf
                      ~loc: cd.pcd_loc
                      "ppx_madge_wrapped_endpoints: constructor with arguments not supported"
                )
                cds
          )
          (ptyp_constr ~loc (loc_lident ~loc "string") [])
      )
  ]

(** Generates
    {|
      type 'w match_<name>s_args = {
          route: 'a 'r. ('a, 'w, 'r) <name> -> ('a, 'w, 'r) Route.t;
          no_route: unit -> 'w;
          dispatch: 'a 'r. ('a, 'w, 'r) <name> -> 'a;
        }
    |}
    which serves as argument for [match_<name>]. It is needed as a record to be able to
    take very general functions.
 *)
let generate_match_args_type ~loc name =
  pstr_type Nonrecursive ~loc [
    type_declaration
      ~loc
      ~name: (Loc.make ~loc @@ match_args_name name)
      ~params: [(ptyp_var ~loc "w", (NoVariance, NoInjectivity))]
      ~manifest: None
      ~private_: Public
      ~cstrs: []
      ~kind: (
        let label_declaration name type_ =
          (* <name>: <type_> *)
          label_declaration ~loc ~name: (Loc.make ~loc name) ~mutable_: Immutable ~type_
        in
        let ptyp_constr_a_w_r name =
          (* ('a, 'w, 'r) <name> *)
          ptyp_constr ~loc (Loc.make ~loc name) [ptyp_var ~loc "a"; ptyp_var ~loc "w"; ptyp_var ~loc "r"]
        in
        let ptyp_poly_arrow_name_to rhs =
          (* 'a 'r. ('a, 'w, 'r) <name> -> ... *)
          ptyp_poly ~loc [Loc.make ~loc "a"; Loc.make ~loc "r"] (
            ptyp_arrow ~loc Nolabel (ptyp_constr_a_w_r (Lident name)) rhs
          )
        in
        Ptype_record [
          label_declaration "route" (ptyp_poly_arrow_name_to (ptyp_constr_a_w_r (Longident.parse "Madge.Route.t")));
          label_declaration "no_route" (ptyp_arrow ~loc Nolabel (ptyp_constr ~loc (loc_lident ~loc "unit") []) (ptyp_var ~loc "w"));
          label_declaration "dispatch" (ptyp_poly_arrow_name_to (ptyp_var ~loc "a"));
        ]
      )
  ]

(** Generates
    {|
      let match_<name> {route; dispatch; no_route} request =
        match
        List.find_map
          (fun (W_<name>' endpoint) ->
            Madge.apply' (route endpoint) (fun () -> dispatch endpoint) request)
          (all_<name>s' ())
        with
        | Some k -> k ()
        | None -> no_route ()
    |}
*)
let generate_match_function ~loc name =
  let ppat_var name = ppat_var ~loc @@ Loc.make ~loc name in
  let pexp_ident name = pexp_ident ~loc @@ loc_lident ~loc name in
  pstr_value ~loc Nonrecursive [
    value_binding
      ~loc
      ~pat: (
        (* match_<name>s : 'w match_<name>s_args -> Madge.Request.t -> 'w *)
        ppat_constraint
          ~loc
          (ppat_var @@ match_name name)
          (
            ptyp_arrow
              ~loc
              Nolabel
              (ptyp_constr ~loc (loc_lident ~loc @@ match_args_name name) [ptyp_var ~loc "w"])
              (
                ptyp_arrow
                  ~loc
                  Nolabel
                  (ptyp_constr ~loc (loc_lident ~loc "Madge.Request.t") [])
                  (ptyp_var ~loc "w")
              )
          )
      )
      ~expr: (
        let ppat_record_field name = (loc_lident ~loc name, ppat_var name) in
        pexp_function
          ~loc
          [
          (* fun {route; no_route; dispatch} request -> *)
          pparam_val ~loc Nolabel None (ppat_record ~loc [ppat_record_field "route"; ppat_record_field "no_route"; ppat_record_field "dispatch"] Closed);
          pparam_val ~loc Nolabel None (ppat_var "request");
          ]
          None
          (
            Pfunction_body (
              pexp_match
                ~loc
                (
                  (* List.find_map (fun ...) (all_<name>s' ()) *)
                  eapply
                    ~loc
                    (pexp_ident "Stdlib.List.find_map")
                    [
                      (
                        (* fun (W_<name>' endpoint) -> *)
                        pexp_fun
                          ~loc
                          Nolabel
                          None
                          (
                            ppat_construct
                              ~loc
                              (loc_lident ~loc @@ w_name ~quot: true name)
                              (Some (ppat_var "endpoint"))
                          )
                          (
                            (* Madge.apply' (route endpoint) (fun () -> dispatch endpoint) request *)
                            eapply
                              ~loc
                              (pexp_ident "Madge.apply'")
                              [
                                eapply ~loc (pexp_ident "route") [pexp_ident "endpoint"];
                                pexp_fun ~loc Nolabel None (ppat_unit ~loc) (eapply ~loc (pexp_ident "dispatch") [pexp_ident "endpoint"]);
                                pexp_ident "request";
                              ]
                          )
                      );
                      eapply ~loc (pexp_ident @@ all_names ~quot: true name) [pexp_unit ~loc];
                    ]
                )
                [
                  (* Some k -> k () | None -> no_route () *)
                  case
                    ~lhs: (ppat_construct ~loc (loc_lident ~loc "Some") (Some (ppat_var "k")))
                    ~guard: None
                    ~rhs: (eapply ~loc (pexp_ident "k") [pexp_unit ~loc]);
                  case
                    ~lhs: (ppat_construct ~loc (loc_lident ~loc "None") None)
                    ~guard: None
                    ~rhs: (eapply ~loc (pexp_ident "no_route") [pexp_unit ~loc]);
                ]
            )
          )
      )
  ]

let generate ~loc name cds = [
  generate_type_wrapped ~quot: false ~loc name;
  generate_type_wrapped ~quot: true ~loc name;
  generate_all_names ~quot: false ~loc name cds;
  generate_all_names ~quot: true ~loc name cds;
  generate_name_function ~loc name cds;
  generate_match_args_type ~loc name;
  generate_match_function ~loc name;
]

let generate ~loc ~path: _ (rec_flag, tds) =
  (
    match rec_flag with
    | Nonrecursive -> Location.raise_errorf ~loc "ppx_madge_wrapped_endpoints: nonrec not supported"
    | _ -> ()
  );
  match tds with
  | [td] ->
    (
      match td.ptype_kind with
      | Ptype_variant cds -> generate ~loc td.ptype_name.txt cds
      | _ -> Location.raise_errorf ~loc "ppx_madge_wrapped_endpoints: kind not supported"
    )
  | _ -> Location.raise_errorf ~loc "ppx_madge_wrapped_endpoints: no or multiple declarations not supported"

let _ = Deriving.add "madge_wrapped_endpoints" ~str_type_decl: (Deriving.Generator.make_noarg generate)
