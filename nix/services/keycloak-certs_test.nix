{ pkgs, config, ... }:
let
  name = "k1-certs";
  inherit (config.services.keycloak.${name}) dataDir;
  realmSrc = ./keycloak/test-realms/test.json;

  sslCertificate = "./keycloak/test-certs/ssl-cert.crt";
  sslCertificateKey = "./keycloak/test-certs/ssl-cert.key";
in
{
  services.keycloak.${name} = {
    enable = true;
    settings.http-port = 8090;

    database.type = "dev-file";

    # They must not end up in the Nix store.
    inherit sslCertificate sslCertificateKey;

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

  # Copy certificates from the Nix store to correct location (only for tests).
  settings.processes.copy-certs =
    let
      cert = ./keycloak/test-certs/ssl-cert.crt;
      certKey = ./keycloak/test-certs/ssl-cert.key;
    in
    {
      command = pkgs.writeShellApplication {
        name = "copy-certs";
        text =
          # Bash
          ''
            echo "Copying certificates (pwd: $(pwd))..."
            mkdir -p "keycloak/test-certs"
            cp "${cert}" "keycloak/test-certs/ssl-cert.crt"
            cp "${certKey}" "keycloak/test-certs/ssl-cert.key"
          '';
      };
    };

  settings.processes.${name} = {
    depends_on.copy-certs.condition = "process_completed_successfully";
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
