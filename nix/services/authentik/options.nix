{
  config,
  lib,
  pkgs,
  name,
  ...
}:

let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    ;

  settingsFormat = pkgs.formats.yaml { };

  hostAndPort = what: defaultPort: {
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Host of the ${what}.";
    };
    port = mkOption {
      type = types.port;
      default = defaultPort;
      description = "Port of the ${what}.";
    };
  };
in
{
  options = {
    components = mkOption {
      type = types.raw;
      example = lib.literalExpression "inputs.authentik-nix.legacyPackages.\${system}.authentikComponents";
      description = ''
        The Authentik component set, typically
        `inputs.authentik-nix.legacyPackages.''${system}.authentikComponents`.
      '';
    };

    secretKey = mkOption {
      type = types.str;
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
          The configuration for the PostgreSQL process Authentik needs.
          Assign it to `services.postgres` of the enclosing `process-compose`
          configuration.
        '';
      };
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      example = "debug";
      description = "Authentik log level.";
    };

    server = {
      http = hostAndPort "server HTTP endpoint" 9000;
      https = hostAndPort "server HTTPS endpoint" 9443;
      metrics = hostAndPort "server metrics endpoint" 9300;
    };

    worker = {
      http = hostAndPort "worker HTTP endpoint" 9001;
      metrics = hostAndPort "worker metrics endpoint" 9302;
    };

    email = hostAndPort "email (SMTP) server used by ${name}" 25;

    postgres = (hostAndPort "PostgreSQL database used by ${name}" 5432) // {
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
          PostgreSQL password, exported as `AUTHENTIK_POSTGRESQL__PASSWORD`
          and used to create the database user.

          This ends up in the Nix store; for non-dev use, override it via
          {option}`environmentFile` (`AUTHENTIK_POSTGRESQL__PASSWORD`).
        '';
      };
    };

    blueprints = {
      export = {
        enable = mkEnableOption "blueprint export process on manual trigger";
        path = mkOption {
          description = "The path to the export file.";
          type = types.pathWith {
            inStore = false;
          };
          default = "${config.dataDir}/export/blueprint.yaml";
        };
      };

      imports = mkOption {
        description = ''
          Blueprints to import.
          They are copied into Authentik's blueprints directory when the
          package is built and are auto-applied by the Authentik worker on
          startup.
        '';
        type = types.listOf (
          types.pathWith {
            inStore = true;
          }
        );
        default = [ ];
      };
    };

    settings = mkOption {
      description = ''
        YAML settings for Authentik which are merged into Authentik's
        `authentik/lib/default.yml`.
      '';
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = { };
      };
    };
  };
}
