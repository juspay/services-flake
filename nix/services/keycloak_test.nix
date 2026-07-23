{ pkgs, config, ... }:
let
  name = "k1";
  inherit (config.services.keycloak.${name}) dataDir;
  realmSrc = ./keycloak/test-realms/test.json;
in
{
  services.keycloak.${name} = {
    enable = true;
    settings.http-port = 8091;

    database.type = "dev-file";

    realms = {
      master = {
        path = ./keycloak/test-realms/master.json;
        export = true;
        import = false;
      };

      test = {
        path = realmSrc;
        import = true;
        export = true;
      };
    };
  };

  settings.processes.test =
    let
      test-export = pkgs.callPackage ./keycloak/test-realms/export.nix {
        process-compose = config.package;
        realmDstDir = "${dataDir}/realm-export";
        pcSocketPath = config.cli.options.unix-socket;
        keycloak-name = name;
      };
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [ test-export ];
        text = "test-export";
        name = "${name}-test";
      };

      depends_on.${name}.condition = "process_healthy";
    };
}
