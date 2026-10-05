{ inputs, ... }:

{
  perSystem =
    { self', pkgs, ... }:
    {
      packages.nes = pkgs.ocamlPackages.buildDunePackage {
        pname = "nes";
        version = "dev";
        src = ../.;

        propagatedBuildInputs = with pkgs.ocamlPackages; [
          dates_calc
          emile
          iso8601
          ppx_monad
          slug
          yojson
        ];

        buildInputs = with pkgs.ocamlPackages; [
          argon2
          logs
          lwt_ppx
          ppx_deriving_yojson
          ppx_import
          ppx_inline_test
          uri
        ];
      };

      packages.madge = pkgs.ocamlPackages.buildDunePackage {
        pname = "madge";
        version = "dev";
        src = ../.;

        propagatedBuildInputs = with pkgs.ocamlPackages; [
          self'.packages.nes
        ];

        buildInputs = with pkgs.ocamlPackages; [
          base
          cohttp-lwt
          cohttp-lwt-jsoo
          cohttp-lwt-unix
          js_of_ocaml-lwt
          logs
          lwt_ppx
          ppx_deriving_yojson
          ppx_fields_conv
          ppx_import
          ppxlib
          prometheus-app
          uri
          yojson
        ];
      };

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

        buildInputs = with pkgs.ocamlPackages; [
          self'.packages.nes
          self'.packages.madge
          self'.packages.sqlgg

          argon2
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
          ppx_monad
          ppx_variants_conv
          prometheus-app
          react
          tyxml
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
          buildInputs = super.buildInputs ++ [ pkgs.ocamlPackages.odoc ];
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
          self'.packages.mybuild
          extlib
          integers
          odoc
          ounit
          ppx_deriving
          yojson
        ];
      };

      ## NOTE: Dependency of sqlgg.
      packages.mybuild = pkgs.ocamlPackages.buildDunePackage rec {
        pname = "mybuild";
        version = "7";
        src = pkgs.fetchFromGitHub {
          owner = "ygrek";
          repo = pname;
          rev = "v${version}";
          sha256 = "sha256-3NBu+8orypL7I8PBU7trI5DA4kbtg8wA/qzyCLUUWYM=";
        };
      };
    };
}
