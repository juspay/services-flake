# Based on Devenv's keycloak module:
# Ref: https://github.com/cachix/devenv/commit/32f6747aabbd5aeb7413bae53d7e01e224ec77bc
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config;

  hasRealmExports = cfg.exportRealms && lib.any (r: r.export.enable) (lib.attrValues cfg.realms);

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
        types.pathWith {
          inStore = false;
        }
      );
      default = null;
      example = "./keycloak/keys/ssl_cert";
      description = ''
        Path to a PEM-formatted certificate used for TLS/SSL connections.
        Relative paths are resolved against `process-compose`'s working
        directory.
      '';
    };

    sslCertificateKey = mkOption {
      type = types.nullOr (
        types.pathWith {
          inStore = false;
        }
      );
      default = null;
      example = "./keycloak/keys/ssl_key";
      description = ''
        Path to a PEM-formatted private key used for TLS/SSL connections.
        Relative paths are resolved against `process-compose`'s working
        directory.
      '';
    };

    plugins = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        Keycloak plugins: `.jar` or `.ear` files, or derivations containing
        them. Pre-packaged plugins are available through
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
            Realms cannot be exported with `realms.«name».export.enable = true`
            when `database.type = "dev-mem"` is used; importing, however, does work.
            Set `exportRealms = false` to disable realm export globally.
          '';
          val;
        description = ''
          The type of database Keycloak should connect to.
          With `dev-mem` the database is discarded on shutdown, so the
          `«name»-realm-export-all` process cannot export any realm.
        '';
      };
    };

    package = mkPackageOption pkgs "keycloak" { };

    initialAdminUsername = mkOption {
      type = types.str;
      default = "admin";
      description = ''
        Initial username set for the temporary admin user.
      '';
    };

    initialAdminPassword = mkOption {
      type = types.str;
      default = "admin";
      description = ''
        Initial password set for the temporary `admin` user.
        This password is not stored securely and should be changed
        immediately in the admin console.

        See [Admin bootstrap and recovery](https://www.keycloak.org/server/bootstrap-admin-recovery) for details.
      '';
    };

    exportRealms = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Global toggle for the realm export process `«name»-realm-export-all`,
        which is created when at least one realm has
        `realms.«name».export.enable = true`.
      '';
    };

    realms = mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            import = mkOption {
              type = types.nullOr (types.pathWith { });
              default = null;
              example = "./realms/a.json";
              description = ''
                The path to import the realm «name» from, either relative to the
                `process-compose` working directory or a Nix store path.
                - If it is not set, this realm is not imported.
                - If it is a relative path and `export.enable` is `true` while
                  `export.path` is unset, it doubles as the export destination.
                  Nix store paths are read-only, so in that case the realm is
                  exported to `''${config.dataDir}/realm-export/«name».json`.
              '';
            };

            export = {
              enable = mkEnableOption "exporting this realm when the `«name»-realm-export-all` process is run";

              path = mkOption {
                type = types.nullOr (
                  types.pathWith {
                    inStore = false;
                  }
                );
                default = null;
                example = "./realms/a.json";
                description = ''
                  The path to export the realm «name» to, relative to the
                  `process-compose` working directory.
                  - If it is not set and `import` is a relative path, `import` is
                    used instead.
                  - Otherwise it defaults to
                    `''${config.dataDir}/realm-export/«name».json`.
                '';
              };
            };
          };
        }
      );

      example = lib.literalExpression ''
        {
          master = {
            export = {
              enable = true;
            };
          };

          test = {
            import = ./realm.json;
            export = {
              enable = true;
            };
          };
        }
      '';

      description = ''
        The realms to import on startup and to export when the
        `«name»-realm-export-all` process is started manually.
      '';
    };

    settings = mkOption {
      type = types.submodule {
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
            '';
          };

          http-relative-path = mkOption {
            type = types.str;
            default = "/";
            example = "/auth";
            apply = x: if lib.hasPrefix "/" x then x else "/" + x;
            description = ''
              The path relative to `/` under which resources are served.
              A missing leading `/` is added automatically.
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
        }
      '';

      description = ''
        Configuration options corresponding to parameters set in
        {file}`conf/keycloak.conf`.

        Most available options are documented at <https://www.keycloak.org/server/all-config>.
      '';
    };
  };
}
