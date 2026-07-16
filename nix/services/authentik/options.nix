{ lib
, ...
}:

let
  inherit (lib)
    mkOption
    types
    ;

  # A relative user-provided path, or a Nix store path (same pattern as keycloak realms).
  blueprintPath = types.nullOr (
    types.either
      (types.pathWith {
        inStore = false;
        absolute = false;
      })
      (types.pathWith { inStore = true; })
  );
in
{
  options = {
    # Authentik is not in nixpkgs, so the package set has to be provided by the user
    # from their own `authentik-nix` flake input. This keeps services-flake input-free.
    components = mkOption {
      type = types.attrsOf types.package;
      example = lib.literalExpression "inputs.authentik-nix.packages.\${system}";
      description = ''
        The Authentik component packages, typically
        `inputs.authentik-nix.packages.''${system}`.

        Must provide at least the following attributes:
        - `gopkgs`            – provides `bin/server`
        - `rust`              – provides `bin/authentik` (the `worker` subcommand)
        - `migrate`           – provides `bin/migrate.py`
        - `staticWorkdirDeps` – the working-directory dependencies
                                (`authentik/`, `blueprints/`, `templates/`, static assets)
        - `manage`            – the management CLI (optional, for blueprint tooling)
      '';
    };

    secretKey = mkOption {
      type = types.nullOr types.str;
      example = "insecure-dev-secret";
      description = ''
        The Authentik secret key, exported as `AUTHENTIK_SECRET_KEY`.

        This is written into the process environment and therefore ends up in the
        Nix store; only use it for local development. For anything else set
        {option}`environmentFile` instead and put `AUTHENTIK_SECRET_KEY` there.
      '';
    };

    initialAdminEmail = mkOption {
      type = types.str;
      default = "admin@example.com";
      description = ''
        E-mail for the bootstrap `akadmin` user, exported as
        `AUTHENTIK_BOOTSTRAP_EMAIL`.
      '';
    };

    initialAdminPassword = mkOption {
      type = types.str;
      default = "admin";
      description = ''
        Initial password for the bootstrap `akadmin` user, exported as
        `AUTHENTIK_BOOTSTRAP_PASSWORD`.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr (
        types.pathWith {
          inStore = false;
          absolute = false;
        }
      );
      default = null;
      example = "authentik.env";
      description = ''
        Path to an environment file with additional
        `AUTHENTIK_*` variables, e.g. `AUTHENTIK_SECRET_KEY` and
        `AUTHENTIK_POSTGRESQL__PASSWORD`.
        Values here override {option}`settings`.
      '';
    };

    services = {
      postgres = mkOption {
        type = types.attrsOf types.raw;
        readOnly = true;
        description = ''
          The config to easily define the needed postgres process.
        '';
      };

      redis = mkOption {
        type = types.attrsOf types.raw;
        readOnly = true;
        description = ''
          The config to easily define the needed redis process.
        '';
      };
    };

    settings = mkOption {
      type = types.submodule {
        options = {
          logLevel = mkOption {
            type = types.str;
            default = "info";
            example = "debug";
            description = "Authentik log level (`log_level`).";
          };

          listen = {
            http = mkOption {
              type = types.str;
              default = "0.0.0.0:9000";
              description = "Address the HTTP server listens on (`listen.listen_http`).";
            };

            https = mkOption {
              type = types.str;
              default = "0.0.0.0:9443";
              description = "Address the HTTPS server listens on (`listen.listen_https`).";
            };
          };

          email = {
            host = mkOption {
              type = types.str;
              default = "localhost";
              description = "Email SMTP server host name.";
            };

            port = mkOption {
              type = types.str;
              default = "localhost";
              description = "Email SMTP server port.";
            };
          };

          postgres = {
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "PostgreSQL host (`postgresql.host`).";
            };

            port = mkOption {
              type = types.port;
              default = 5432;
              description = "PostgreSQL port (`postgresql.port`).";
            };

            name = mkOption {
              type = types.str;
              default = "authentik";
              description = "PostgreSQL database name (`postgresql.name`).";
            };

            user = mkOption {
              type = types.str;
              default = "authentik";
              description = "PostgreSQL user (`postgresql.user`).";
            };

            password = mkOption {
              type = types.str;
              default = "authentik";
              description = ''
                PostgreSQL password (`postgresql.password`). Written to the config
                file in the Nix store; for non-dev use, override it via
                {option}`environmentFile` (`AUTHENTIK_POSTGRESQL__PASSWORD`).
              '';
            };
          };

          redis = {
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "Redis host (`redis.host`).";
            };

            port = mkOption {
              type = types.port;
              default = 6379;
              description = "Redis port (`redis.port`).";
            };
          };

          blueprints = mkOption {
            default = { };
            type = types.attrsOf (
              types.submodule {
                options = {
                  path = mkOption {
                    type = blueprintPath;
                    default = null;
                    example = "./blueprints/my-blueprint.yaml";
                    description = ''
                      Path (relative to the `process-compose` working dir, or a Nix store
                      path) of a blueprint YAML file to make available for import.
                    '';
                  };

                  import = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Whether to make this blueprint available for import.";
                  };
                };
              }
            );

            example = lib.literalExpression ''
              {
                my-app = {
                  path = ./blueprints/my-app.yaml;
                };
              }
            '';

            description = ''
              Blueprints to import on start up.
              Enabled blueprints are copied into the blueprints directoryr and
              auto-applied by the Authentik worker.
            '';
          };
        };
      };

      default = { };

      example = lib.literalExpression ''
        {
          log_level = "debug";
          listen.listen_http = "0.0.0.0:9002";
          postgresql.host = "127.0.0.1";
          email = {
            host = "localhost";
            port = 25;
          };
        }
      '';

      description = ''
        Authentik configuration, rendered to a `local.yml` file that Authentik loads
        from its working directory. Corresponds to the keys documented at
        <https://docs.goauthentik.io/docs/install-config/configuration/>.

        Authentik config is hierarchical YAML, so allow arbitrary nested keys.
        It is not well documented.
        See the default: <https://raw.githubusercontent.com/goauthentik/authentik/main/authentik/lib/default.yml>

        The defaults point PostgreSQL/Redis at the companion
        `services.postgres."authentik-db-pg"` and
        `services.redis."authentik-db-redis"` instances used in the example and test.
      '';
    };
  };
}
