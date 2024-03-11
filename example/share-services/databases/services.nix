{ inputs }:
{ ... }: {
  services.postgres."pg1" = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialDatabases = [
      {
        name = "sample";
        schemas = [ "${inputs.northwind}/northwind.sql" ];
      }
    ];
    # Required due to socket length being limited to 100 chars, see: https://github.com/juspay/services-flake/pull/77
    socketDir = "$HOME/.services/postgres/pg1";
  };

  services.postgres."pg2" = {
    enable = true;
    listen_addresses = "127.0.0.1";
    port = 5433;
    socketDir = "$HOME/.services/postgres/pg2";
  };

  # Start `pg2-init` process after `pg1-init` to avoid race condition for creating
  # the `data` directory on the first run.
  settings.processes."pg2-init".depends_on."pg1-init".condition = "process_completed_successfully";

}
