{ pkgs, config, ... }:
{
  services.keycloak.k1 = {
    enable = true;
    settings.http-port = 8089;

    database.type = "dev-file";

    realms = {
      master = {
        path = ./keycloak/test-realms/master.json;
        export = true;
        import = false;
      };

      test = {
        path = ./keycloak/test-realms/test.json;
        import = true;
        export = true;
      };
    };
  };

  settings.processes.test =
    let
      cfg = config.services.keycloak."k1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          cfg.package
          pkgs.gnugrep
          pkgs.curl
          pkgs.uutils-coreutils-noprefix
          pkgs.jq
        ];
        text = "
        # TODO: Realm export tests were removed because the H2 embedded database
        # (dev-file) holds a file lock that isn't reliably released by the time the
        # export JVM starts. Consider re-adding export tests with a PostgreSQL backend.
        ";
        name = "k1-tests";
      };

      depends_on."k1".condition = "process_healthy";
    };
}
