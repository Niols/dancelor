{ inputs, ... }:

{
  perSystem =
    {
      self',
      pkgs,
      lib,
      ...
    }:
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
          self'.packages.ocaml-argon2

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
          self'.packages.prometheus-app

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
          self'.packages.ocaml-argon2
          self'.packages.prometheus-app
          self'.packages.sqlgg

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

      packages.ocaml-argon2 = pkgs.ocamlPackages.buildDunePackage {
        pname = "argon2";
        version = "dev";
        src = pkgs.fetchFromGitHub {
          owner = "khady";
          repo = "ocaml-argon2";
          rev = "1.0.2";
          sha256 = "sha256-m5yOMT33Z9LfjQg6QRBW6mjHNyIySq6somTFuGmL9xI=";
        };

        propagatedBuildInputs =
          (with pkgs; [ libargon2 ])
          ++ (with pkgs.ocamlPackages; [
            ctypes
            ctypes-foreign
            result
          ]);

        buildInputs = with pkgs.ocamlPackages; [
          dune-configurator
        ];
      };

      packages.prometheus-app = pkgs.ocamlPackages.buildDunePackage rec {
        pname = "prometheus-app";
        version = "1.2";

        src = pkgs.fetchurl {
          url = "https://github.com/mirage/prometheus/releases/download/v${version}/prometheus-${version}.tbz";
          sha256 = "sha256-g2Q6ApprbecdFANO7i6U/v8dCHVcSkHVg9wVMKtVW8s=";
        };

        duneVersion = "3";

        propagatedBuildInputs = with pkgs.ocamlPackages; [
          alcotest
          astring
          asetmap
          cohttp-lwt-unix
          fmt
          logs
          lwt
          prometheus
          re
        ];

        meta = {
          description = "Client library for Prometheus monitoring";
          license = lib.licenses.asl20;
          maintainers = [ lib.maintainers.ulrikstrid ];
        };
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
