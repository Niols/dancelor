{ ... }:

{
  nodes.machine =
    { pkgs, ... }:
    {
      virtualisation = {
        cores = 2;
        memorySize = 2048;
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
    };

  testScript =
    let
      dump =
        db:
        "sudo -u dancelor pg_dump"
        + " --schema-only"
        + " --exclude-table=migrations"
        + " --quote-all-identifiers"
        + " --no-owner"
        + " --no-comments"
        + " --no-publications"
        + " --no-security-labels"
        + " --no-subscriptions"
        + " --no-table-access-method"
        + " --no-tablespaces"
        + " --no-toast-compression"
        + " --no-unlogged-table-data"
        + " --restrict-key=ybiQOqa6jiLe8LvxFznU4q8n34iwf9VXgUBS2e7j5NMdWOEHU3ms2YSbcIZ871W"
        + " ${db}";
    in
    ''
      machine.start()
      machine.wait_for_unit("dancelor.service")

      ## The `dancelor` database now has the schema produced by migrations.
      ## Create a second database and import schema.sql directly into it.
      machine.succeed("sudo -u postgres createdb --owner=dancelor dancelor_from_schema")
      machine.succeed("sudo -u dancelor psql --dbname=dancelor_from_schema --file=${../src/server/database/schema-extra-before.sql}")
      machine.succeed("sudo -u dancelor psql --dbname=dancelor_from_schema --file=${../src/server/database/schema.sql}")
      machine.succeed("sudo -u dancelor psql --dbname=dancelor_from_schema --file=${../src/server/database/schema-extra-after.sql}")

      ## Dump both schemas and compare.
      machine.succeed("${dump "dancelor"} > /tmp/from-migrations.sql")
      machine.succeed("${dump "dancelor_from_schema"} > /tmp/from-schema.sql")
      machine.succeed("diff --unified /tmp/from-migrations.sql /tmp/from-schema.sql >&2")
    '';
}
