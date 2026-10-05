{ inputs, ... }:

{
  perSystem =
    { self', pkgs, ... }:
    {
      packages.dancelor = pkgs.ocamlPackages.buildDunePackage {
        pname = "dancelor";
        version = "dev";
        src = ../.;

        nativeBuildInputs = [
          self'.packages.sqlgg
        ]
        ++ (with pkgs.ocamlPackages; [
          menhir
          js_of_ocaml
        ])
        ++ (with pkgs; [ sassc ]);

        propagatedBuildInputs = with pkgs.ocamlPackages; [
          dates_calc
          emile
          iso8601
          ppx_monad
          slug
          yojson
        ];

        buildInputs = with pkgs.ocamlPackages; [
          self'.packages.sqlgg

          argon2
          base
          cohttp
          cohttp-lwt
          cohttp-lwt-jsoo
          cohttp-lwt-unix
          js_of_ocaml-lwt
          js_of_ocaml-ppx
          js_of_ocaml-tyxml
          logs
          lwt_ppx
          lwt_react
          menhirLib
          monadise
          monadise-lwt
          omd
          postgresql
          ppx_blob
          ppx_deriving_qcheck
          ppx_deriving_yojson
          ppx_fields_conv
          ppx_import
          ppx_inline_test
          ppxlib
          ppx_monad
          ppx_variants_conv
          prometheus-app
          react
          tyxml
          uri
          yojson
        ];
      };

      packages.documentation =
        let
          super = self'.packages.dancelor;
        in
        pkgs.stdenv.mkDerivation {
          name = "${super.name}-documentation";
          ## Grabbing super's buildInputs is overkill in terms of dependencies,
          ## but most often we will also build the package, so it is fine.
          inherit (super) src nativeBuildInputs;
          buildInputs = super.buildInputs ++ super.propagatedBuildInputs ++ [ pkgs.ocamlPackages.odoc ];
          buildPhase = "dune build @doc";
          installPhase = "cp -R _build/default/_doc/_html $out";
        };

      packages.sqlgg = pkgs.ocamlPackages.buildDunePackage rec {
        pname = "sqlgg";
        version = "dev";
        src = inputs.sqlgg;
        nativeBuildInputs = with pkgs.ocamlPackages; [
          menhir
        ];
        buildInputs = with pkgs.ocamlPackages; [
          extlib
          integers
          odoc
          ounit
          ppx_deriving
          ppx_deriving_hash
          ppx_deriving_variant_string
          ppx_enumerate
          yojson
        ];
      };
    };
}
