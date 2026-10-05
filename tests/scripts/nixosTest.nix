{ lib, ... }:

let
  inherit (lib)
    mkForce
    ;

in
{
  nodes.machine =
    { pkgs, ... }:
    {
      virtualisation = {
        cores = 4;
        memorySize = 8192;
      };

      services.dancelor = {
        enable = true;
        listeningPort = 8080;
        githubTokenFile = "${pkgs.writeText "github-token" "dummy github token"}";
        githubRepository = "github.com/niols/dancelor";
        githubDatabaseRepository = "github.com/niols/dancelor-database";
        testMode = true;
      };

      services.postgresql.package = pkgs.postgresql_15;

      environment.systemPackages = [ pkgs.postgresql_15 ];

      ## Add a small systemd unit that injects the test database into
      ## PostgreSQL. It must run after PostgreSQL has booted up but
      ## before Dancelor.
      systemd.services.inject-test-database = {
        after = [
          "postgresql.service"
          "postgresql-setup.service"
        ];
        requires = [
          "postgresql.service"
          "postgresql-setup.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "dancelor";
          ExecStart = "${pkgs.postgresql_15}/bin/psql --dbname=dancelor --file=${../database.sql}";
        };
      };
      systemd.services.dancelor = {
        after = [ "inject-test-database.service" ];
        requires = [ "inject-test-database.service" ];
        serviceConfig.Restart = mkForce "no"; # only try starting once
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("dancelor.service")
    machine.succeed("cd ${../..} && pytest --numprocesses auto --verbose >&2")
  '';
}
