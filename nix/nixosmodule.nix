{ self, inputs, ... }:

{
  flake.nixosModules.dancelor =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkIf;
      cfg = config.services.dancelor;
    in
    {
      options.services.dancelor = {
        enable = lib.mkEnableOption "Enable the Dancelor service";

        listeningPort = lib.mkOption {
          type = lib.types.int;
          default = 6872;
          description = "Port on which Dancelor will listen.";
        };

        githubTokenFile = lib.mkOption {
          type = lib.types.str;
          description = ''
            Path to a file that contains the GitHub API token.

            This is used by the issue report mechanism and must therefore be allowed to open issues on the repositories.
          '';
        };

        githubRepository = lib.mkOption {
          type = lib.types.str;
          description = ''
            Dancelor's GitHub repository

            This is used by the issue report mechanism. It must contain the host, owner, and repository.
          '';
          example = "github.com/niols/dancelor";
        };

        githubDatabaseRepository = lib.mkOption {
          type = lib.types.str;
          description = ''
            Dancelor's database's GitHub repository - used by the error reporting mechanism.

            This is used by the issue report mechanism. It must contain the host, owner, and repository.
          '';
          example = "github.com/niols/dancelor-database";
        };

        routineThreads = lib.mkOption {
          type = lib.types.int;
          description = ''
            Number of threads used by routines.
          '';
          default = 2;
          example = 8;
        };

        testMode = lib.mkOption {
          type = lib.types.bool;
          description = ''
            Whether to set up Dancelor for testing. Do not use in production.
          '';
          default = false;
        };
      };

      config = lib.mkIf cfg.enable (
        let
          inherit (lib) toJSON;
          inherit (pkgs) writeText writeShellApplication;
          inherit (pkgs.stdenv.hostPlatform) system;

          socketPath = "/run/postgresql";

          run-dancelor = writeShellApplication {
            name = "dancelor";
            text = ''
              exec ${self.apps.${system}.dancelor.program} ${
                writeText "dancelor-config" (toJSON {
                  port = cfg.listeningPort;
                  database = {
                    driver = "postgresql";
                    endpoint = [
                      "Socket"
                      socketPath
                    ];
                    database = "dancelor";
                    user = "dancelor";
                    password = null;
                  };
                  share = "${self.packages.${system}.dancelor}/share/dancelor";
                  github_token = "";
                  github_token_file = cfg.githubTokenFile;
                  github_repository = cfg.githubRepository;
                  github_database_repository = cfg.githubDatabaseRepository;
                  nixpkgs = inputs.nixpkgs;
                  routine_threads = cfg.routineThreads;
                  pid_file = "";
                  init_only = false;
                  loglevel = {
                    cases = [ ];
                    default = if cfg.testMode then "info" else "warning";
                  };
                })
              }
            '';
          };

        in
        {
          ## User and group `dancelor:dancelor`.
          users.users.dancelor = {
            isSystemUser = true;
            group = "dancelor";
          };
          users.groups.dancelor = { };

          ## Systemd service running Dancelor and restarting it constantly.
          ##
          systemd.services.dancelor = {
            after = [
              "network.target"
              "postgresql.target"
            ];
            requires = [ "postgresql.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "notify";
              NotifyAccess = "all";
              ExecStart = "${run-dancelor}/bin/dancelor";
              Restart = "always";
              User = "dancelor";
              Group = "dancelor";
              LimitNOFILE = 8092; # default soft max is 1024, which can easily be exhausted
            };
          };

          ## PostgreSQL with a `dancelor` database and user
          ##
          ## NOTE: We might want to leave some of this configuration to the
          ## client code, but since it's mostly us we can keep it for now.
          ## Better over-specify and have Nix catch our mistakes later.
          ##
          ## NOTE: We expect a specific major version of PostgreSQL, but we
          ## leave it to the host to set it; the assertion catches any
          ## desynchronisation.
          ##
          assertions = [
            {
              assertion = config.services.postgresql.package.psqlSchema == "15";
              message = "Dancelor expects PostgreSQL 15, but services.postgresql.package is ${config.services.postgresql.package.name}.";
            }
          ];
          services.postgresql = {
            enable = true;
            ensureDatabases = [ "dancelor" ];
            ensureUsers = [
              {
                name = "dancelor";
                ensureDBOwnership = true;
              }
            ];
            settings.unix_socket_directories = socketPath;
            authentication = mkIf cfg.testMode "local all all trust";
          };
        }
      );
    };
}
