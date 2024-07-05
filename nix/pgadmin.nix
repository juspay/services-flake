# Based on https://github.com/NixOS/nixpkgs/blob/d53c2037394da6fe98decca417fc8fda64bf2443/nixos/modules/services/admin/pgadmin.nix
{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;

  _base = with types; [ int bool str ];
  base = with types; oneOf ([ (listOf (oneOf _base)) (attrsOf (oneOf _base)) ] ++ _base);

  formatAttrset = attr:
    "{${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${builtins.toJSON key}: ${formatPyValue value},") attr)}}";

  formatPyValue = value:
    if builtins.isString value then builtins.toJSON value
    else if value ? _expr then value._expr
    else if builtins.isInt value then toString value
    else if builtins.isBool value then (if value then "True" else "False")
    else if builtins.isAttrs value then (formatAttrset value)
    else if builtins.isList value then "[${lib.concatStringsSep "\n" (map (v: "${formatPyValue v},") value)}]"
    else throw "Unrecognized type";

  formatPy = attrs:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "${key} = ${formatPyValue value}") attrs);

  pyType = with types; attrsOf (oneOf [ (attrsOf base) (listOf base) base ]);
in
{
  options = {
    enable = lib.mkEnableOption name;

    package = lib.mkPackageOption pkgs "pgadmin4" { };

    host = lib.mkOption {
      description = lib.mdDoc "Host for pgadmin4 to run on";
      type = types.str;
      default = "localhost";
    };

    port = lib.mkOption {
      description = lib.mdDoc "Port for pgadmin4 to run on";
      type = types.port;
      default = 5050;
    };


    initialEmail = lib.mkOption {
      description = "Initial email for the pgAdmin account";
      type = types.str;
    };

    initialPassword = lib.mkOption {
      description = "Initial password for the pgAdmin account";
      type = types.str;
    };

    minimumPasswordLength = lib.mkOption {
      description = "Minimum length of the password";
      type = types.int;
      default = 6;
    };

    dataDir = lib.mkOption {
      type = types.str;
      default = "./data/${name}";
      description = "The pgadmin4 data directory";
    };

    extraDefaultConfig = lib.mkOption {
      type = pyType;
      internal = true;
      readOnly = true;
      default = {
        DATA_DIR = {
          _expr = "os.getenv('PGADMIN_DATADIR')";
        };
        DEFAULT_SERVER = config.host;
        DEFAULT_SERVER_PORT = config.port;
        PASSWORD_LENGTH_MIN = config.minimumPasswordLength;
        SERVER_MODE = true;
        UPGRADE_CHECK_ENABLED = false;
      };
    };

    extraConfig = lib.mkOption {
      type = pyType;
      default = { };
      description = "Additional config for pgadmin4";
    };
  };

  config = {
    outputs = {
      settings = {
        processes =
          let
            pgadminConfig = pkgs.writeTextDir "config_local.py" (
              "import os\n" + (formatPy
                (lib.recursiveUpdate config.extraDefaultConfig config.extraConfig))
            );
          in
          {
            "${name}-init" =
              let
                setupScript = pkgs.writeShellApplication {
                  name = "setup-pgadmin";
                  runtimeInputs =
                    [ config.package ] ++
                    (lib.lists.optionals pkgs.stdenv.isDarwin [
                      pkgs.coreutils
                    ]);
                  text = ''
                    export PYTHONPATH="${pgadminConfig}"
                    PGADMIN_DATADIR="$(readlink -m ${config.dataDir})"
                    mkdir -p "$PGADMIN_DATADIR"
                    export PGADMIN_DATADIR
                    PGADMIN_SETUP_EMAIL=${lib.escapeShellArg config.initialEmail}
                    export PGADMIN_SETUP_EMAIL
                    PGADMIN_SETUP_PASSWORD=${lib.escapeShellArg config.initialPassword}
                    export PGADMIN_SETUP_PASSWORD
                    if [ -f ${config.package}/bin/.pgadmin4-setup-wrapped ]; then
                      # pgadmin-7.5 has .pgadmin4-setup-wrapped
                      ${config.package}/bin/.pgadmin4-setup-wrapped setup
                    else
                      # pgadmin-8.2 has .pgadmin4-cli-wrapped
                      ${config.package}/bin/.pgadmin4-cli-wrapped setup-db
                    fi
                  '';
                };
              in
              {
                command = setupScript;
              };

            "${name}" =
              let
                startScript = pkgs.writeShellApplication {
                  name = "start-pgadmin";
                  runtimeInputs =
                    [ config.package ] ++
                    (lib.lists.optionals pkgs.stdenv.isDarwin [
                      pkgs.coreutils
                    ]);
                  text = ''
                    export PYTHONPATH="${pgadminConfig}"
                    PGADMIN_DATADIR="$(readlink -m ${config.dataDir})"
                    export PGADMIN_DATADIR
                    PGADMIN_SETUP_EMAIL=${lib.escapeShellArg config.initialEmail}
                    export PGADMIN_SETUP_EMAIL
                    PGADMIN_SETUP_PASSWORD=${lib.escapeShellArg config.initialPassword}
                    export PGADMIN_SETUP_PASSWORD
                    ${config.package}/bin/.pgadmin4-wrapped
                  '';
                };
              in
              {
                command = startScript;
                readiness_probe = {
                  http_get = {
                    host = config.host;
                    port = config.port;
                    path = "/misc/ping";
                  };
                  initial_delay_seconds = 2;
                  period_seconds = 10;
                  timeout_seconds = 4;
                  success_threshold = 1;
                  failure_threshold = 5;
                };
                depends_on."${name}-init".condition = "process_completed_successfully";
                # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
                availability.restart = "on_failure";
              };
          };
      };
    };
  };
}
