{ config
, lib
, pkgs
, name
, ...
}:

let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    ;

  settingsFormat = pkgs.formats.yaml { };

  hostAndPort = name: port: {
    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host of the ${name}.";
    };
    port = mkOption {
      type = types.port;
      default = port;
      description = "Port of the ${name}.";
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
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      example = "debug";
      description = "Authentik log level.";
    };

    server = {
      http = hostAndPort "server endpoint" 9000;
      https = hostAndPort "server endpoint" 9443;
      metrics = hostAndPort "server metrics endpoint." 9300;
    };

    worker = {
      http = hostAndPort "worker endpoint" 9001;
      metrics = hostAndPort "worker metrics endpoint." 9302;
    };

    email = hostAndPort "${name}'s email connection" 25;

    postgres = (hostAndPort "${name}'s postgres DB" 5432) // {
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

    blueprints = {
      export = {
        enable = mkEnableOption "blueprint export process on manual trigger";
        path = mkOption {
          description = "The path to the export file.";
          type = types.pathWith {
            inStore = false;
            absolute = false;
          };
          default = "${config.dataDir}/export/blueprint.yaml";
        };
      };

      imports = mkOption {
        description = ''
          Blueprints to import on start up.
          Enabled blueprints are copied into the blueprints directoryr and
          auto-applied by the Authentik worker.
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
      description = "YAML option for authentic which are merged with '<dataDir>/authentic/lib/default.yml'.";
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = { };
      };
    };
  };
}
