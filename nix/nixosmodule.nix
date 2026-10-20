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
      inherit (lib)
        mkIf
        mkEnableOption
        mkOption
        types
        ;
      inherit (pkgs) writeShellApplication formats;
      inherit (pkgs.stdenv.hostPlatform) system;

      cfg = config.services.dancelor;
      settingsFormat = formats.json { };
      ## FIXME: validate settings file at eval time
      settingsFile = settingsFormat.generate "dancelor-settings.json" cfg.settings;
    in
    {
      options.services.dancelor = {
        enable = mkEnableOption "Enable the Dancelor service";

        testMode = mkOption {
          type = types.bool;
          description = ''
            Whether to set up Dancelor for testing. In particular, this enables
            [settings.test.die_on_exn] and lowers default loglevel to [info].
          '';
          default = false;
        };

        settings = mkOption {
          type = types.submodule {
            freeformType = settingsFormat.type;
          };
          default = { };
          description = ''
            Configuration for Dancelor, see
            <link xlink:href="https://github.com/Niols/dancelor/blob/main/src/server/config.ml"/>
            for supported values.
          '';
        };
      };

      config = mkIf cfg.enable (
        let
          socketPath = "/run/postgresql";

          run-dancelor = writeShellApplication {
            name = "dancelor";
            text = "exec ${self.apps.${system}.dancelor.program} ${settingsFile}";
          };

        in
        {
          services.dancelor.settings = {
            database = {
              driver = "postgresql";
              endpoint = [
                "Socket"
                socketPath
              ];
            };
            nixpkgs = inputs.nixpkgs;
            share = "${self.packages.${system}.dancelor}/share/dancelor";
            test.die_on_exn = cfg.testMode;
            loglevel.default = if cfg.testMode then "info" else "debug";
          };

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
              Restart = if cfg.testMode then "no" else "always";
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
