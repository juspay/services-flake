# Based on Devenv's keycloak module:
# Ref: https://github.com/cachix/devenv/commit/32f6747aabbd5aeb7413bae53d7e01e224ec77bc
{ config
, lib
, pkgs
, ...
}:

let
  cfg = config;

  hasRealmExports = lib.any (lib.mapAttrsToList (realmName: opts: opts.export.enable) cfg.realms);

  inherit (lib)
    mkOption
    mkPackageOption
    mkEnableOption
    types
    ;
in
{
  options = {
    sslCertificate = mkOption {
      type = types.nullOr (
        lib.types.pathWith {
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

    sslCertificateKey = mkOption {
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

    plugins = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        Keycloak plugin jar, ear files or derivations containing
        them. Packaged plugins are available through
        `pkgs.keycloak.plugins`.
      '';
    };

    database = {
      type = mkOption {
        type = types.enum [
          "dev-mem"
          "dev-file"
        ];
        default = "dev-file";
        example = "dev-mem";
        apply =
          val:
            assert lib.assertMsg (val == "dev-mem" -> !hasRealmExports) ''
              You cannot export realms with `realms.«name».export == true` when
              using `database.type == 'dev-mem'`, import however works.
              You can disable realms export with `exportRealms = true` globally.
            '';
            val;
        description = ''
          The type of database Keycloak should connect to.
          If you use `dev-mem`, the realm export over script
          `keycloak-realm-export-*` does not work.
        '';
      };
    };

    package = mkPackageOption pkgs "keycloak" { };

    initialAdminPassword = mkOption {
      type = types.str;
      default = "admin";
      description = ''
        Initial password set for the temporary `admin` user.
        The password is not stored safely and should be changed
        immediately in the admin panel.

        See [Admin bootstrap and recovery](https://www.keycloak.org/server/bootstrap-admin-recovery) for details.
      '';
    };

    exportRealms = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Global toggle to enable/disable the realms export process `keycloak-realm-export-all`
        if any realms have `realms.«name».export == true`.
      '';
    };

    realms = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            import = mkOption {
              type = types.nullOr (
                # A relative, user-provided path.
                lib.types.either
                  (lib.types.pathWith {
                    inStore = false;
                    absolute = false;
                  })
                  # A nix store path.
                  (lib.types.pathWith { inStore = true; })
              );
              default = null;
              example = "./realms/a.json";
              description = ''
                The path (relative to the `process-compose` working dir or an Nix store path)
                where you want to import (or export) this realm «name» to.
                - If not set and `import` is `true` this realm is not imported.
                - If
                  - set to an Nix store path
                  - or not it is not set
                  and `export` is `true` then
                  it is exported to `''${config.dataDir}/realm-export/«name».json`.
              '';
            };

            export = {
              enable = mkEnableOption ''
                export the realm on process launch `<name>-export-realms`.
              '';

              path = mkOption {
                type = types.nullOr (
                  lib.types.pathWith {
                    inStore = false;
                    absolute = false;
                  }
                );
                default = null;
                example = "./realms/a.json";
                description = ''
                  The path (relative to the `process-compose` working dir or an Nix store path)
                  where you want to export this realm «name» to.
                  - If not set and `import.path` is relative it is used as default.
                  - If not set otherwise its defaulted to a value in the data folder.
                '';
              };
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

    settings = mkOption {
      type = lib.types.submodule {
        freeformType = types.attrsOf (
          types.nullOr (
            types.oneOf [
              types.str
              types.int
              types.bool
              (types.attrsOf types.path)
            ]
          )
        );

        options = {
          http-host = mkOption {
            type = types.str;
            default = "::";
            example = "::1";
            description = ''
              On which address Keycloak should accept new connections.
            '';
          };

          http-port = mkOption {
            type = types.port;
            default = 8080;
            example = 8080;
            description = ''
              On which port Keycloak should listen for new HTTP connections.
            '';
          };

          http-management-port = mkOption {
            type = types.port;
            default = 9000;
            example = 9000;
            description = ''
              The port where Keycloak exposes management API endpoints (e.g. `/health`).
            '';
          };

          https-port = mkOption {
            type = types.port;
            default = 34429;
            example = 34429;
            description = ''
              On which port Keycloak should listen for new HTTPS connections.
              If its not set, its disabled.
            '';
          };

          http-relative-path = mkOption {
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

          hostname = mkOption {
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
}
