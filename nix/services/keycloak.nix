# Based on https://github.com/cachix/devenv/blob/main/src/modules/services/keycloak.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    package = lib.mkPackageOption pkgs "keycloak" { };

    initialAdminPassword = lib.mkOption {
      type = types.str;
      default = "admin";
      description = ''
          Initial password set for the temporary `admin` user.
        The password is not stored safely and should be changed
        immediately in the admin panel.

        See [Admin bootstrap and recovery](https://www.keycloak.org/server/bootstrap-admin-recovery) for details.
      '';
    };

    sslCertificate = lib.mkOption {
      type = types.nullOr (
        types.pathWith {
          inStore = false;
          absolute = false;
        }
      );
      default = null;
      example = "/run/keys/ssl_cert";
      description = ''
          The path to a PEM formatted certificate to use for TLS/SSL
        connections.
      '';
    };

    sslCertificateKey = lib.mkOption {
      type = types.nullOr (
        types.pathWith {
          inStore = false;
          absolute = false;
        }
      );
      default = null;
      example = "/run/keys/ssl_key";
      description = ''
          The path to a PEM formatted private key to use for TLS/SSL
        connections.
      '';
    };

    plugins = lib.mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
          Keycloak plugin jar, ear files or derivations containing
        them. Packaged plugins are available through
        `pkgs.keycloak.plugins`.
      '';
    };

    database = {
      type = lib.mkOption {
        type = types.enum [
          "dev-mem"
          "dev-file"
        ];
        default = "dev-file";
        example = "dev-mem";
        description = ''
            The type of database Keycloak should connect to.
          If you use `dev-mem`, the realm export over script
          `keycloak-realm-export-*` does not work.
        '';
      };
    };

    scripts = {
      exportRealm = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
            Global toggle to enable/disable the **single** realm export
          script `keycloak-realm-export`.
        '';
      };
    };

    processes = {
      exportRealms = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
            Global toggle to enable/disable the realms export process `keycloak-realm-export-all`
          if any realms have `realms.«name».export == true`.
        '';
      };
    };

    realms = lib.mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            path = lib.mkOption {
              type = types.nullOr (
                types.pathWith {
                  inStore = false;
                  absolute = false;
                }
                # types.path
              );
              default = null;
              example = "./realms/a.json";
              description = ''
                  The path (string, relative to `DEVENV_ROOT`) where you want to import (or export) this realm «name» to.
                If not set and `import` is `true` this realm is not imported.
                If not set and `export` is `true` its exported to `$DEVENV_STATE/keycloak/realm-export/«name».json`.
              '';
            };

            import = lib.mkOption {
              type = types.bool;
              default = true;
              example = true;
              description = ''
                If you want to import that realm on start up, if the realm does not yet exist.
              '';
            };

            export = lib.mkOption {
              type = types.bool;
              default = false;
              example = true;
              description = ''
                If you want to export that realm on process/script launch `keycloak-export-realms`.
              '';
            };
          };
        }
      );

      example = lib.literalExpression ''
          {
          myrealm = {
            path = "./myfolder/export.json";
            import = true; # default
            export = true;
          };
        }
      '';

      description = ''
          Specify the realms you want to import on start up and
        export on a manual start of process/script 'keycloak-realm-export-all'.
      '';
    };

    settings = lib.mkOption {
      default = { };
      type = types.submodule {
        freeformType = types.attrsOf (
          types.nullOr (types.oneOf [
            types.str
            types.int
            types.bool
            (types.attrsOf types.path)
          ])
        );

        options = {
          http-host = lib.mkOption {
            type = types.str;
            default = "::";
            example = "::1";
            description = ''
              On which address Keycloak should accept new connections.
            '';
          };

          http-port = lib.mkOption {
            type = types.port;
            default = 8080;
            example = 8080;
            description = ''
              On which port Keycloak should listen for new HTTP connections.
            '';
          };

          https-port = lib.mkOption {
            type = types.port;
            default = 34429;
            example = 34429;
            description = ''
                On which port Keycloak should listen for new HTTPS connections.
              If its not set, its disabled.
            '';
          };

          http-relative-path = lib.mkOption {
            type = types.str;
            default = "/";
            example = "/auth";
            apply = x: if !(lib.hasPrefix "/") x then "/" + x else x;
            description = ''
                The path relative to `/` for serving
              resources.

              ::: {.note}
              In versions of Keycloak using Wildfly (&lt;17),
              this defaulted to `/auth`. If
              upgrading from the Wildfly version of Keycloak,
              i.e. a NixOS version before 22.05, you'll likely
              want to set this to `/auth` to
              keep compatibility with your clients.

              See <https://www.keycloak.org/migration/migrating-to-quarkus>
              for more information on migrating from Wildfly to Quarkus.
              :::
            '';
          };

          hostname = lib.mkOption {
            type = types.str;
            default = "localhost";
            example = "localhost";
            description = ''
                The hostname part of the public URL used as base for
              all frontend requests.

              See <https://www.keycloak.org/server/hostname>
              for more information about hostname configuration.
            '';
          };
        };
      };

      example = lib.literalExpression ''
          {
          hostname = "localhost";
          https-key-store-file = "/path/to/file";
          https-key-store-password = { _secret = "/run/keys/store_password"; };
        }
      '';

      description = ''
          Configuration options corresponding to parameters set in
        {file}`conf/keycloak.conf`.

        Most available options are documented at <https://www.keycloak.org/server/all-config>.

        Options containing secret data should be set to an attribute
        set containing the attribute `_secret` - a
        string pointing to a file containing the value the option
        should be set to. See the example to get a better picture of
        this: in the resulting
        {file}`conf/keycloak.conf` file, the
        `https-key-store-password` key will be set
        to the contents of the
        {file}`/run/keys/store_password` file.
      '';
    };
  };

  config = {
    outputs.settings.processes.${name} =
      let
        is-secret = v: lib.isAttrs v && v ? _secret && lib.isString v._secret;

        dummy-certificates = pkgs.stdenv.mkDerivation {
          pname = "dev-ssl-cert";
          version = "1.0";
          buildInputs = [ pkgs.openssl ];
          src = null;
          dontUnpack = true;
          buildPhase = ''
                mkdir -p $out
            openssl req -x509 -newkey rsa:2048 -nodes \
              -keyout $out/ssl-cert.key -out $out/ssl-cert.crt \
              -days 365 \
              -subj "/CN=localhost"
          '';

          installPhase = "true";
        };

        provided-ssl-certs = config.sslCertificate != null && config.sslCertificateKey != null;

        # Generate the keycloak config file to build it.
        keycloak-config = lib.generators.toKeyValue {
          mkKeyValue = lib.flip lib.generators.mkKeyValueDefault "=" {
            mkValueString =
              v:
              if builtins.isInt v then
                toString v
              else if builtins.isString v then
                v
              else if true == v then
                "true"
              else if false == v then
                "false"
              else if is-secret v then
                builtins.hashString "sha256" v._secret
              else
                throw "unsupported type ${builtins.typeOf v}: ${(lib.generators.toPretty { }) v}";
          };
        };

        # Filters empty values out.
        filtered-config = lib.converge
          (lib.filterAttrsRecursive (
            _: v:
              !builtins.elem v [
                { }
                null
              ]
          ))
          config.settings;

        final-config = {
          http-enabled = true;
          db = config.database.type;
          health-enabled = true;
          http-management-relative-path = "/";
          http-management-port = "9000";
          log-console-level = "info";
          log-level = "info";

          https-certificate-file =
            if provided-ssl-certs then config.sslCertificate else "${dummy-certificates}/ssl-cert.crt";
          https-certificate-key-file =
            if provided-ssl-certs then config.sslCertificateKey else "${dummy-certificates}/ssl-cert.key";
        } // filtered-config;

        # Write the keycloak config file.
        conf-file = pkgs.writeText "keycloak.conf" (keycloak-config final-config);

        # Generate the command to import realms.
        realm-import = lib.mapAttrsToList
          (
            realm: e:
              let
                f = config.dataDir + "/" + e.path;
              in
              ''
                echo "Symlinking realm file '${f}' to import path '$KC_HOME_DIR/data/import'."
                if [ ! -f "${f}" ]; then
                  echo "Realm file '${f}' does not exist!" >&2
                  exit 1
                fi
                ln -fs $(readlink -f "${f}") "$KC_HOME_DIR/data/import/"
              ''
          )
          (lib.filterAttrs (_: v: v.import && v.path != null) config.realms);

        keycloak-build = (
          config.package.override {
            confFile = conf-file;
            plugins = config.package.enabledPlugins ++ config.plugins;
          }
        );

        keycloak-start = pkgs.writeShellScriptBin "keycloak-start" ''
          set -euo pipefail
          mkdir -p "$KC_HOME_DIR"
          mkdir -p "$KC_HOME_DIR/conf"
          mkdir -p "$KC_HOME_DIR/tmp"

          # Always remove the symlinks for the realm's exports
          rm -rf "$KC_HOME_DIR/data/import" || true
          mkdir -p "$KC_HOME_DIR/data/import"

          ln -fs ${keycloak-build}/providers "$KC_HOME_DIR/"
          ln -fs ${keycloak-build}/lib "$KC_HOME_DIR/"
          install -D -m 0600 ${conf-file} "$KC_HOME_DIR/conf/keycloak.conf"

          echo "Keycloak config:"
          ${lib.getExe' keycloak-build "kc.sh"} show-config || true

          echo "Import realms (if any)..."
          ${builtins.concatStringsSep "\n" realm-import}
          echo "========================="

          echo "Start Keycloak..."
          exec ${lib.getExe' keycloak-build "kc.sh"} start --optimized --import-realm
        '';
      in
      {
        command = "${lib.getExe keycloak-start}";

        environment = {
          KC_HOME_DIR = config.dataDir + "/keycloak";
          KC_CONF_DIR = config.dataDir + "/keycloak/conf";
          KC_TMP_DIR = config.dataDir + "/keycloak/tmp";

          KC_BOOTSTRAP_ADMIN_USERNAME = "admin";
          KC_BOOTSTRAP_ADMIN_PASSWORD = "${lib.escapeShellArg config.initialAdminPassword}";
        };

        readiness_probe =
          let
            admin-ready = pkgs.writeShellApplication {
              name = "keycloak-admin-ready";
              runtimeInputs = [ pkgs.curl ];
              text = ''
                curl -k --head -fsS \
                  "https://localhost:${toString final-config.http-management-port}${lib.removeSuffix "/" final-config.http-management-relative-path}/health/ready";
              '';
            };
          in
          {
            exec.command = lib.getExe admin-ready;
            initial_delay_seconds = 15;
            period_seconds = 10;
            timeout_seconds = 2;
            success_threshold = 1;
            failure_threshold = 5;
          };

        # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
        availability = {
          restart = "on_failure";
          max_restarts = 5;
        };
      };
  };
}
