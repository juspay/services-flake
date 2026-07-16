{ config
, lib
, pkgs
, name
, ...
}:
let
  # The authentik components.
  gopkgs = requireComponent "gopkgs";
  rust = requireComponent "rust";
  rawMigrate = requireComponent "migrate";
  pythonEnv = requireComponent "pythonEnv";
  staticWorkdirDeps = requireComponent "staticWorkdirDeps";

  requireComponent =
    attr:
    if config.components ? ${attr} then
      config.components.${attr}
    else
      throw ''
        services.authentik.${name}.authentikComponents is missing the `${attr}` attribute.
        (see the module docs).
      '';

  # NOTE: Workaround -> authentik-nix's `migrate` ships `bin/migrate.py`, a shell wrapper that execs an inner
  # `bin/.migrate.py-wrapped` whose shebang is `#!/usr/bin/env python`.
  # `/usr/bin/env` does not exist in the Nix build sandbox that
  # `nix build .#checks…` (`just test`) runs the process-compose stack in,
  # so the migration crashes with "bad interpreter".
  migrate = pkgs.runCommand "authentik-migrate-sandbox-safe" { } ''
    cp -R --no-preserve=mode,ownership ${rawMigrate} $out
    substituteInPlace $out/bin/.migrate.py-wrapped \
      --replace-fail '#!/usr/bin/env python' '#!${pythonEnv}/bin/python'
    substituteInPlace $out/bin/migrate.py \
      --replace-fail '${rawMigrate}/bin/.migrate.py-wrapped' "$out/bin/.migrate.py-wrapped"
    chmod +x "$out/bin/.migrate.py-wrapped" "$out/bin/migrate.py"
  '';

  # HTTP port for the readiness probe, parsed from `listen.listen_http` (e.g. "0.0.0.0:9000").
  httpPort = lib.last (lib.splitString ":" config.settings.listen.http);

  # NOTE: We would rather set a config.yaml,
  # but documentation is pretty bad and not sufficient for certain stuff
  # Therefore we set env variables as described.
  connEnv = {
    AUTHENTIK_POSTGRESQL__HOST = config.settings.postgres.host;
    AUTHENTIK_POSTGRESQL__PORT = toString config.settings.postgres.port;
    AUTHENTIK_POSTGRESQL__NAME = config.settings.postgres.name;
    AUTHENTIK_POSTGRESQL__USER = config.settings.postgres.user;
    AUTHENTIK_POSTGRESQL__PASSWORD = config.settings.postgres.password;

    AUTHENTIK_REDIS__HOST = config.settings.redis.host;
    AUTHENTIK_REDIS__PORT = toString config.settings.redis.port;

    AUTHENTIK_LISTEN__HTTP = config.settings.listen.http;
    AUTHENTIK_LISTEN__HTTPS = config.settings.listen.https;
    AUTHENTIK_LOG_LEVEL = config.settings.logLevel;
  };

  baseEnv = connEnv // {
    AUTHENTIK_SECRET_KEY = config.secretKey;
    AUTHENTIK_BOOTSTRAP_PASSWORD = config.initialAdminPassword;
    AUTHENTIK_BOOTSTRAP_EMAIL = config.initialAdminEmail;
  };

  # Copy the enabled blueprints into the Authentik blueprints dir.
  # Copied (not symlinked) for the same reason as the built-in
  # blueprints: authentik rejects blueprints whose resolved path escapes `blueprints_dir`.
  blueprintImport = lib.mapAttrsToList
    (
      bp: e:
        # Bash
        ''
          f=$(realpath "${e.path}")
          echo "Copying blueprint '${bp}' from '$f' into './blueprints'."
          if [ ! -f "$f" ]; then
            echo "Blueprint file '$f' does not exist!" >&2
            exit 1
          fi
          cp -L "$f" "./blueprints/"
          chmod u+w "./blueprints/$(basename "$f")"
          unset f
        ''
    )
    (lib.filterAttrs (_: v: v.import && v.path != null) config.settings.blueprints);

  loadEnvFile = lib.optionalString (config.environmentFile != null) ''
    echo "Load extra authentic environment file '${config.environmentFile}'."
    set -a
    # shellcheck disable=SC1091
    . "${config.environmentFile}"
    set +a
  '';

  runtimeEnv = ''
    dataDir="$(realpath ${config.dataDir})"
    echo "Authentik data dir: '$dataDir'."

    mkdir -p "$dataDir/media" "$dataDir/certs" "$dataDir/prometheus"

    export AUTHENTIK_STORAGE__FILE__PATH="$dataDir"
    export AUTHENTIK_STORAGE__MEDIA__FILE__PATH="$dataDir/media"
    export AUTHENTIK_CERT_DISCOVERY_DIR="$dataDir/certs"
    export AUTHENTIK_BLUEPRINTS_DIR="$dataDir/blueprints"
    export PROMETHEUS_MULTIPROC_DIR="$dataDir/prometheus"
    export AUTHENTIK_TEMPLATE_DIR="$dataDir/templates";

    cd "$dataDir"
  '';

  setup = ''
    set -euo pipefail
    ${runtimeEnv}
    ${loadEnvFile}

    echo "Working dir: $(pwd)"

    # Bring in Authentik's working-directory dependencies (authentik/, templates/, static
    # assets, ...) but manage `blueprints/` ourselves so we can add user blueprints.
    for dep in ${staticWorkdirDeps}/*; do
      base=$(basename "$dep")
      [ "$base" = "blueprints" ] && continue

      echo "Symlinking '$dep' -> '$base'"
      ln -sfn "$dep" "./$base"
    done

    # Combined blueprints dir: Authentik's built-in blueprints + user-provided ones.
    # These must be COPIED (not symlinked): A symlink into the nix store resolves
    # outside the dir and is rejected, which crashes the server's bootstrap worker.
    rm -rf ./blueprints
    mkdir -p ./blueprints
    if [ -d "${staticWorkdirDeps}/blueprints" ]; then
      cp -rL "${staticWorkdirDeps}/blueprints/." ./blueprints/
    fi
    chmod -R u+w ./blueprints
    ${builtins.concatStringsSep "\n" blueprintImport}
  '';

  authentik-migrate =
    pkgs.writeShellScriptBin "authentik-migrate"
      # Bash
      ''
        ${setup}
        echo "Starting authentik migrate ..."
        exec ${migrate}/bin/migrate.py
      '';

  authentik-worker =
    pkgs.writeShellScriptBin "authentik-worker"
      # Bash
      ''
        ${runtimeEnv}
        ${loadEnvFile}
        echo "Starting authentik worker ..."
        exec ${rust}/bin/authentik worker
      '';

  authentik-server =
    pkgs.writeShellScriptBin "authentik-server"
      # Bash
      ''
        ${runtimeEnv}
        ${loadEnvFile}
        echo "Starting authentik server ..."
        exec ${gopkgs}/bin/server
      '';

  authentik-health =
    pkgs.writeShellScriptBin "authentik-health"
      # Bash
      ''
        ${pkgs.curl}/bin/curl -fsS "http://localhost:${httpPort}/-/health/ready/"
      '';
in
{
  services = {
    postgres = {
      "${name}-pg-db" = {
        enable = true;
        port = config.settings.postgres.port;
        initialScript.before = ''
          CREATE USER \"${config.settings.postgres.user}\" WITH PASSWORD '${config.settings.postgres.password}' CREATEDB;
          CREATE DATABASE \"${config.settings.postgres.name}\" OWNER \"${config.settings.postgres.user}\"
        '';
      };
    };

    redis = {
      "${name}-redis-db" = {
        enable = true;
        port = config.settings.redis.port;
      };
    };
  };

  outputs = {
    settings.processes = {
      "${name}-migrate" = {
        description = "Authentik database migrations: a prerequisite that creates the schema.";
        environment = baseEnv;
        command = "${lib.getExe authentik-migrate}";

        depends_on = {
          "${name}-pg-db".condition = "process_healthy";
          "${name}-redis-db".condition = "process_healthy";
        };
      };

      "${name}-worker" = {
        description = "Authentik background worker: processes tasks and applies blueprints.";
        environment = baseEnv;
        command = "${lib.getExe authentik-worker}";
        depends_on."${name}-migrate".condition = "process_completed_successfully";
      };

      "${name}" = {
        description = "Authentik HTTP/API server.";
        environment = baseEnv;
        command = "${lib.getExe authentik-server}";

        depends_on = {
          "${name}-migrate".condition = "process_completed_successfully";
          "${name}-worker".condition = "process_started";
        };

        readiness_probe = {
          exec.command = "${lib.getExe authentik-health}";
          initial_delay_seconds = 20;
          period_seconds = 5;
          timeout_seconds = 4;
          failure_threshold = 30;
        };
      };
    };
  };
}
