{ inputs }:
let
  globalSocket = { name, ... }: {
    # Required due to socket length being limited to 100 chars, see: https://github.com/juspay/services-flake/pull/77
    socketDir = "$HOME/.services/postgres/${name}";
  };
in
{
  services.postgres."northwind" = {
    imports = [ globalSocket ];
    enable = true;
    listen_addresses = "127.0.0.1";
    initialDatabases = [
      {
        name = "sample";
        schemas = [ "${inputs.northwind}/northwind.sql" ];
      }
    ];
  };
}
