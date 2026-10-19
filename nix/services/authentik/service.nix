{
  config,
  lib,
  pkgs,
  name,
  ...
}:
let
  cfg = config;
  dataDir = cfg.dataDir;

  settingsFormat = pkgs.formats.yaml { };

  settingsFile = settingsFormat.generate "authentik.yml" cfg.settings;

  modStaticWorkdirDeps =
    prev: authentik-src:
    prev.overrideAttrs (oA: {
      buildCommand =
        oA.buildCommand
        +
        # Bash
        ''
          rm -v $out/authentik
          cp -r --no-preserve=mode,ownership ${authentik-src}/authentik $out/authentik
          src="authentik/lib/default.yml"
          echo "Merging settings file into '$src'."
          ${lib.getExe pkgs.yq-go} eval-all '. as $item ireduce ({}; . *+ $item)' \
            "${authentik-src}/$src" "${settingsFile}" > "$out/$src"

          # Set blueprints_dir, template_dir.
          ${lib.getExe pkgs.yq-go} -i ".blueprints_dir = \"$out/blueprints\"" "$out/$src"
          ${lib.getExe pkgs.yq-go} -i ".email.templates_dir = \"$out/templates\"" "$out/$src"

          if grep -q '^ *blueprints_dir: */blueprints' "$out/$src"; then
            echo "Blueprints directory must no longer point to '/blueprints'."
            exit 1
          fi
          chmod -R -w $out/authentik

          echo "Placing blueprints."
          rm -v $out/blueprints
          cp -vr --no-preserve=mode,ownership ${authentik-src}/blueprints $out/blueprints
          cd "$out/blueprints"
          ${lib.concatStringsSep "\n" blueprintImport}
        '';
    });

  finalComponents = cfg.components.overrideScope (
    final: prev:
    let
      prevComps = prev.authentikComponents;
    in
    {
      authentikComponents = prevComps // {
        manage = prevComps.manage;
        migrate = prevComps.migrate;
        staticWorkdirDeps = modStaticWorkdirDeps prevComps.staticWorkdirDeps prev.authentik-src;
      };
    }
  );

  # The authentik components.
  inherit (finalComponents.authentikComponents) manage;
  inherit (finalComponents.authentikComponents) rust;
  inherit (finalComponents.authentikComponents) migrate;
  inherit (finalComponents.authentikComponents) pythonEnv;
  inherit (finalComponents.authentikComponents) staticWorkdirDeps;

  connEnv =
    assert allPortsUnique;
    {
      # Note: All AUTHENTIK_ prefixed variables are
      # override values in the default.yaml.

      AUTHENTIK_SECRET_KEY = cfg.secretKey;
      AUTHENTIK_BOOTSTRAP_PASSWORD = cfg.initialAdminPassword;
      AUTHENTIK_BOOTSTRAP_EMAIL = cfg.initialAdminEmail;

      # The Rust components compile `authentik/lib/default.yml` into the binary
      # (`include_str!`) and only read `/etc/authentik/config.yml`,
      # `/etc/authentik/config.d/*.yml` and `<cwd>/local.yml` from disk -- never
      # the copy patched in `modStaticWorkdirDeps`. Only Python picks that one
      # up, so the connection settings have to be passed as environment
      # variables or the worker talks to upstream's `localhost:5432` default.
      AUTHENTIK_POSTGRESQL__HOST = cfg.postgres.host;
      AUTHENTIK_POSTGRESQL__PORT = toString cfg.postgres.port;
      AUTHENTIK_POSTGRESQL__USER = cfg.postgres.user;
      AUTHENTIK_POSTGRESQL__NAME = cfg.postgres.name;
      AUTHENTIK_POSTGRESQL__PASSWORD = cfg.postgres.password;

      AUTHENTIK_LOG_LEVEL = cfg.logLevel;
    };

  allPortsUnique =
    let
      allPorts = [
        cfg.server.http.port
        cfg.server.https.port
        cfg.server.metrics.port
        cfg.postgres.port

        cfg.worker.http.port
        cfg.worker.metrics.port
      ];
    in
    lib.assertMsg (lib.allUnique allPorts) "Some ports in `authentik.server`, `authentik.worker` are identical: ${toString allPorts}.";

  listenEnv =
    type:
    let
      c = cfg.${type};
    in
    {
      AUTHENTIK_LISTEN__HTTP = "${c.http.host}:${toString c.http.port}";
      AUTHENTIK_LISTEN__METRICS = "${c.metrics.host}:${toString c.metrics.port}";
    }
    // lib.optionalAttrs (c ? https) {
      AUTHENTIK_LISTEN__HTTPS = "${c.https.host}:${toString c.https.port}";
    };

  # Copy the enabled blueprints into the Authentik blueprints dir.
  # Copied (not symlinked) for the same reason as the built-in
  # blueprints: authentik rejects blueprints whose resolved path escapes `blueprints_dir`.
  blueprintImport = lib.map (
    p:
    # Bash
    ''
      filename="${lib.baseNameOf p}"
      f="${p}"
      echo "Copying blueprint '${p}' from '$f' into './additional/$filename'."
      mkdir -p ./additional
      cp -L "$f" "./additional/$filename"
    '') cfg.blueprints.imports;

  loadEnvFile =
    lib.optionalString (cfg.environmentFile != null)
      # Bash
      ''
        echo "Loading extra Authentik environment file '${cfg.environmentFile}'."
        set -a
        # shellcheck disable=SC1091
        . "${cfg.environmentFile}"
        set +a
      '';

  # `component` is used to give every process its own temporary directory:
  # the server and the worker both bind `$TMPDIR/authentik.sock` and
  # `$TMPDIR/authentik-metrics.sock`, so a shared `TMPDIR` makes them fight
  # over the same socket paths (the server adds `authentik-gunicorn.sock` and
  # `authentik_gunicorn_tmp/` on top of that). Upstream gets
  # away with one name because each component runs in its own container (and
  # the NixOS module runs them as `DynamicUser`, hence `PrivateTmp`).
  runtimeEnv =
    component:
    # Bash
    ''
      dataDir="$(realpath ${dataDir})"
      staticDir="$dataDir/static"

      echo "Authentik data dir: '$dataDir'."
      echo "Authentik static dir: '$staticDir'."

      mkdir -p "$dataDir/data" \
               "$dataDir/media" \
               "$dataDir/certs" \
               "$dataDir/prometheus"

      # Set up the temporary directory, one per component.
      mkdir -p "$dataDir/temp"
      if [ -L "$dataDir/temp/${component}" ]; then
        tmpDir=$(readlink "$dataDir/temp/${component}")
      else
        tmpDir=$(mktemp -d)
        ln -fs "$tmpDir" "$dataDir/temp/${component}"
      fi
      mkdir -p "$tmpDir"

      export TMPDIR="$tmpDir"
      export TEMPDIR="$TMPDIR"

      export PROMETHEUS_MULTIPROC_DIR="$dataDir/prometheus"

      export PATH="${pythonEnv}/bin:$PATH"

      # Bring in Authentik's working-directory dependencies
      # (authentik/, static assets, ...).
      if [ ! -d "$staticDir" ]; then
        ln -sf "${staticWorkdirDeps}" "$staticDir"
      fi
      ls -al "$staticDir"

      echo "Settings file '$staticDir/authentik/lib/default.yml':"
      echo "====================="
      cat "$staticDir/authentik/lib/default.yml"
      echo "====================="
    '';

  setup =
    component:
    # Bash
    ''
      ${runtimeEnv component}
      ${loadEnvFile}
    '';

  authentik-migrate =
    pkgs.writeShellScriptBin "authentik-migrate"
      # Bash
      ''
        ${setup "migrate"}
        cd "$staticDir"
        echo "Starting authentik migrate ..."
        exec ${migrate}/bin/migrate.py
      '';

  authentik-worker =
    pkgs.writeShellScriptBin "authentik-worker"
      # Bash
      ''
        ${setup "worker"}
        cd "$staticDir"
        echo "Starting authentik worker ..."
        exec ${rust}/bin/authentik worker
      '';

  authentik-server =
    pkgs.writeShellScriptBin "authentik-server"
      # Bash
      ''
        ${setup "server"}
        cd "$staticDir"
        echo "Starting authentik server ..."
        exec ${rust}/bin/authentik server
      '';

  authentik-blueprint-export =
    pkgs.writeShellScriptBin "authentik-blueprint-export"
      # Bash
      ''
        ${setup "blueprint-export"}
        echo "Starting authentik blueprint export to '${cfg.blueprints.export.path}'..."
        mkdir -p "$(dirname "${cfg.blueprints.export.path}")"
        exec ${manage}/bin/manage.py export_blueprint > "${cfg.blueprints.export.path}"
      '';

  authentik-health =
    pkgs.writeShellScriptBin "authentik-health"
      # Bash
      ''
        ${pkgs.curl}/bin/curl -fsS "http://${cfg.server.http.host}:${toString cfg.server.http.port}/-/health/ready/"
      '';

  # The worker has no health endpoint; its metrics server answers on every
  # path, and it is only started once the config parsed and the database pool
  # came up, which is what we want to gate on.
  authentik-worker-health =
    pkgs.writeShellScriptBin "authentik-worker-health"
      # Bash
      ''
        ${pkgs.curl}/bin/curl -fsS -o /dev/null "http://${cfg.worker.metrics.host}:${toString cfg.worker.metrics.port}/"
      '';
in
{
  services = {
    postgres = {
      "${name}-pg-db" = {
        enable = cfg.enable;
        port = cfg.postgres.port;
        initialScript.before = pkgs.writeText "before" ''
          CREATE USER "${cfg.postgres.user}" WITH PASSWORD '${cfg.postgres.password}' CREATEDB;
          CREATE DATABASE "${cfg.postgres.name}" OWNER "${cfg.postgres.user}";
        '';
      };
    };
  };

  settings = {
    log_level = lib.mkDefault cfg.logLevel;

    cert_discovery_dir = lib.mkDefault "${dataDir}/certs";

    # Both of these make outbound HTTP calls on startup. In an offline or
    # sandboxed stack they fail and `update_latest_version` is then retried by
    # dramatiq with backoff, logging a full traceback each time.
    disable_update_check = lib.mkDefault true;
    disable_startup_analytics = lib.mkDefault true;

    postgresql = {
      host = lib.mkDefault cfg.postgres.host;
      port = lib.mkDefault cfg.postgres.port;
      user = lib.mkDefault cfg.postgres.user;
      password = lib.mkDefault cfg.postgres.password;
      name = lib.mkDefault cfg.postgres.name;
    };

    storage = {
      file = lib.mkDefault {
        path = "${dataDir}/data";
      };

      media = {
        backend = lib.mkDefault "file";
        file = lib.mkDefault {
          path = "${dataDir}/media";
        };
      };
    };
  };

  outputs.settings.processes = lib.mkIf cfg.enable (
    {
      "${name}-migrate" = {
        description = "Authentik database migrations: a prerequisite that creates the schema.";
        environment = connEnv;
        command = "${lib.getExe authentik-migrate}";

        depends_on = {
          "${name}-pg-db".condition = "process_healthy";
        };
      };

      "${name}-worker" = {
        description = "Authentik background worker: processes tasks and applies blueprints.";
        environment = connEnv // listenEnv "worker";
        command = "${lib.getExe authentik-worker}";
        depends_on."${name}-migrate".condition = "process_completed_successfully";

        readiness_probe = {
          exec.command = "${lib.getExe authentik-worker-health}";
          initial_delay_seconds = 10;
          period_seconds = 5;
          timeout_seconds = 4;
          failure_threshold = 30;
        };
      };

      "${name}" = {
        description = "Authentik HTTP/API server.";
        environment = connEnv // listenEnv "server";
        command = "${lib.getExe authentik-server}";

        depends_on = {
          "${name}-migrate".condition = "process_completed_successfully";
          "${name}-worker".condition = "process_healthy";
        };

        readiness_probe = {
          exec.command = "${lib.getExe authentik-health}";
          initial_delay_seconds = 20;
          period_seconds = 5;
          timeout_seconds = 4;
          failure_threshold = 30;
        };
      };
    }
    // lib.optionalAttrs cfg.blueprints.export.enable {
      "${name}-blueprint-export" = {
        disabled = true;
        description = "Authentik blueprint export.";
        environment = connEnv // listenEnv "worker";
        command = "${lib.getExe authentik-blueprint-export}";
      };
    }
  );
}
