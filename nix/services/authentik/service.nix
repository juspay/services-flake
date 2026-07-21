{ config
, lib
, pkgs
, name
, ...
}:
let
  cfg = config;
  dataDir = cfg.dataDir;

  settingsFormat = pkgs.formats.yaml { };

  # NOTE: Workaround -> authentik-nix's `migrate` ships `bin/migrate.py`, a shell wrapper that execs an inner
  # `bin/.migrate.py-wrapped` whose shebang is `#!/usr/bin/env python`.
  # `/usr/bin/env` does not exist in the Nix build sandbox that
  # `nix build .#checks…` (`just test`) runs the process-compose stack in,
  # so the migration crashes with "bad interpreter".
  makeSandboxSafe =
    prev: name: pythonEnv:
    pkgs.runCommand "authentik-migrate-sandbox-safe" { }
      # Bash
      ''
        cp -R --no-preserve=mode,ownership ${prev} $out
        wrapped="$out/bin/.${name}.py-wrapped"
        normal="$out/bin/${name}.py"

        substituteInPlace "$wrapped" \
          --replace-fail '#!/usr/bin/env python' '#!${pythonEnv}/bin/python'
        substituteInPlace  "$normal" \
          --replace-fail '${prev}/bin/.${name}.py-wrapped' "$wrapped"
        chmod +x "$out/bin/.${name}.py-wrapped" "$out/bin/${name}.py"
      '';

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
          ${lib.getExe pkgs.yq-go} -i ".templates_dir = \"$out/templates\"" "$out/$src"

          cat "$src" | grep -v "/blueprints" || {
            echo "Blueprints directory must not anymore point to /blueprints."
            exit 1
          }
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
          manage = makeSandboxSafe prevComps.manage "manage" prevComps.pythonEnv;
          migrate = makeSandboxSafe prevComps.migrate "migrate" prevComps.pythonEnv;
          staticWorkdirDeps = modStaticWorkdirDeps prevComps.staticWorkdirDeps prev.authentik-src;
        };
      }
  );

  # The authentik components.
  inherit (finalComponents.authentikComponents) manage;
  inherit (finalComponents.authentikComponents) gopkgs;
  inherit (finalComponents.authentikComponents) rust;
  inherit (finalComponents.authentikComponents) migrate;
  inherit (finalComponents.authentikComponents) pythonEnv;
  inherit (finalComponents.authentikComponents) staticWorkdirDeps;

  connEnv =
    assert allPortsUnique;
    {
      AUTHENTIK_SECRET_KEY = cfg.secretKey;
      AUTHENTIK_BOOTSTRAP_PASSWORD = cfg.initialAdminPassword;
      AUTHENTIK_BOOTSTRAP_EMAIL = cfg.initialAdminEmail;
    };

  allPortsUnique =
    let
      allPorts = [
        cfg.server.http.port
        cfg.server.https.port
        cfg.server.metrics.port

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
  blueprintImport = lib.map
    (
      p:
      # Bash
      ''
        filename="${lib.baseNameOf p}"
        f="${p}"
        echo "Copying blueprint '${p}' from '$f' into './additional/$filename'."
        mkdir -p ./additional
        cp -L "$f" "./additional/$filename"
      ''
    )
    cfg.blueprints.imports;

  loadEnvFile =
    lib.optionalString (cfg.environmentFile != null)
      # Bash
      ''
        echo "Load extra authentic environment file '${cfg.environmentFile}'."
        set -a
        # shellcheck disable=SC1091
        . "${cfg.environmentFile}"
        set +a
      '';

  runtimeEnv =
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

      # Set temp. dir.
      if [ ! -L "$dataDir/temp" ]; then
        tmpDir=$(mktemp -d)
        mkdir -p "$tmpDir"
        ln -s "$tmpDir" "$dataDir/temp"
      fi
      export TMPDIR="$dataDir/temp"
      export TEMPDIR="$TMPDIR"

      export PROMETHEUS_MULTIPROC_DIR="$dataDir/prometheus"

      export PATH="${pythonEnv}/bin:$PATH"

      # Bring in Authentik's working-directory dependencies
      # (authentik/, templates/, static assets, ...).
      if [ ! -d "$staticDir" ]; then
        ln -s "${staticWorkdirDeps}" "$staticDir"
      fi
      ls -al "$staticDir"

      echo "Settings file '$staticDir/authentik/lib/default.yml':"
      echo "====================="
      cat "$staticDir/authentik/lib/default.yml"
      echo "====================="
    '';

  setup =
    # Bash
    ''
      set -euo pipefail
      ${runtimeEnv}
      ${loadEnvFile}
    '';

  authentik-migrate =
    pkgs.writeShellScriptBin "authentik-migrate"
      # Bash
      ''
        ${setup}
        cd "$staticDir"
        echo "Starting authentik migrate ..."
        exec ${migrate}/bin/migrate.py
      '';

  authentik-worker =
    pkgs.writeShellScriptBin "authentik-worker"
      # Bash
      ''
        ${setup}
        cd "$staticDir"
        echo "Starting authentik worker ..."
        exec ${rust}/bin/authentik worker
      '';

  authentik-blueprint-export =
    pkgs.writeShellScriptBin "authentik-worker"
      # Bash
      ''
        ${setup}
        echo "Starting authentik blueprint export to '${cfg.blueprints.export.path}'..."
        mkdir -p "$(dirname "${cfg.blueprints.export.path}")"
        exec ${manage}/bin/manage.py export_blueprint > "${cfg.blueprints.export.path}"
      '';

  authentik-server =
    pkgs.writeShellScriptBin "authentik-server"
      # Bash
      ''
        ${setup}
        cd "$staticDir"
        echo "Starting authentik server ..."
        exec ${gopkgs}/bin/server
      '';

  authentik-health =
    pkgs.writeShellScriptBin "authentik-health"
      # Bash
      ''
        ${pkgs.curl}/bin/curl -fsS "http://${cfg.server.http.host}:${toString cfg.server.http.port}/-/health/ready/"
      '';
in
{
  services = {
    postgres = {
      "${name}-pg-db" = {
        enable = cfg.enable;
        port = cfg.postgres.port;
        initialScript.before = ''
          CREATE USER \"${cfg.postgres.user}\" WITH PASSWORD '${cfg.postgres.password}' CREATEDB;
          CREATE DATABASE \"${cfg.postgres.name}\" OWNER \"${cfg.postgres.user}\"
        '';
      };
    };
  };

  settings = {
    log_level = lib.mkDefault cfg.logLevel;

    cert_discovery_dir = lib.mkDefault "${dataDir}/certs";

    postgresql = {
      user = lib.mkDefault cfg.postgres.user;
      name = lib.mkDefault cfg.postgres.name;
      host = lib.mkDefault cfg.postgres.host;
      port = lib.mkDefault cfg.postgres.port;
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
      };

      "${name}" = {
        description = "Authentik HTTP/API server.";
        environment = connEnv // listenEnv "server";
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
    }
    // lib.optionalAttrs (cfg.blueprints.export.enable) {
      "${name}-blueprint-export" = {
        disabled = true;
        description = "Authentik blueprint export.";
        environment = connEnv // listenEnv "worker";
        command = "${lib.getExe authentik-blueprint-export}";
      };
    }
  );
}
