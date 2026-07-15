{ config
, lib
, pkgs
, name
, ...
}:
let
  cfg = config;

  isSecret = v: lib.isAttrs v && v ? _secret && lib.isString v._secret;

  # Generate the keycloak config file to build it.
  keycloakConfig = lib.generators.toKeyValue {
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
        else if isSecret v then
          builtins.hashString "sha256" v._secret
        else
          throw "unsupported type ${builtins.typeOf v}: ${(lib.generators.toPretty { }) v}";
    };
  };

  # Filters empty values out.
  filteredConfig = lib.converge
    (lib.filterAttrsRecursive (
      _: v:
        !builtins.elem v [
          { }
          null
        ]
    ))
    cfg.settings;

  # Write the keycloak config file.
  confFile = pkgs.writeText "keycloak.conf" (keycloakConfig filteredConfig);

  # Build keycloak derivation.
  keycloakBuild = (
    cfg.package.override {
      inherit confFile;

      plugins = cfg.package.enabledPlugins ++ cfg.plugins;
    }
  );

  # Create dummy certificate derivation.
  dummyCertificates = pkgs.stdenv.mkDerivation {
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

  providedSSLCerts = cfg.sslCertificate != null && cfg.sslCertificateKey != null;

  # Generate the command to import realms.
  realmImport = lib.mapAttrsToList
    (
      realm: e:
        let
          f = e.path;
        in
        ''
          echo "Symlinking realm file '${f}' to import path '$KC_HOME_DIR/data/import'."
          if [ ! -f "${f}" ]; then
            echo "Realm file '${f}' does not exist!" >&2
            exit 1
          fi
          ln -fs "${f}" "$KC_HOME_DIR/data/import/"
        ''
    )
    (lib.filterAttrs (_: v: v.import && v.path != null) cfg.realms);

  # Generate the commands to export realms.
  assertKeycloakStopped = [
    ''
      if ${keycloak-health}/bin/keycloak-health &>/dev/null; then
        echo "You must first stop keycloak and then run this command again." >&2
        exit 1
      fi

      # Ensure the KC_HOME_DIR is set up for the export command.
      mkdir -p "$KC_HOME_DIR/conf"
      ln -fs ${keycloakBuild}/providers "$KC_HOME_DIR/"
      ln -fs ${keycloakBuild}/lib "$KC_HOME_DIR/"
      install -D -m 0600 ${confFile} "$KC_HOME_DIR/conf/keycloak.conf"
    ''
  ];

  keycloak-realm-export = pkgs.writeShellScriptBin "keycloak-realm-export" (
    lib.concatStringsSep "\n" (
      assertKeycloakStopped
      ++ [
        ''
          ${keycloakBuild}/bin/kc.sh export --optimized --realm "$1" --file "$2"
        ''
      ]
    )
  );

  realmExportPath =
    let
      isInStore =
        x:
        lib.path.hasStorePathPrefix (
          if builtins.isPath x then x else /. + builtins.unsafeDiscardStringContext x
        );
    in
    realm: e:
      if (e.path == null || isInStore e.path) then
        (config.dataDir + "/realm-export/${realm}.json")
      else
        e.path;

  realmsToExport = lib.filterAttrs (_: v: v.export) cfg.realms;
  realmsExport =
    if (!cfg.processes.exportRealms || lib.length (lib.attrNames realmsToExport) == 0) then
      [ ]
    else
      assertKeycloakStopped
      ++ lib.mapAttrsToList
        (
          realm: e:
            let
              file = realmExportPath realm e;
            in
            ''
              echo "Exporting realm '${realm}' to '${file}'."
              mkdir -p "$(dirname "${file}")"
              ${keycloakBuild}/bin/kc.sh export --optimized --realm "${realm}" --file "${file}"

              echo "Beautifying realm export '${file}' for diffing."
              temp_file=$(${pkgs.coreutils}/bin/mktemp)
              ${pkgs.jq}/bin/jq --sort-keys . "${file}" > "$temp_file"
              ${pkgs.coreutils}/bin/mv "$temp_file" "${file}"
            ''
        )
        realmsToExport;

  keycloak-realm-export-all = pkgs.writeShellScriptBin "keycloak-realm-export-all" (
    lib.concatStringsSep "\n" realmsExport
  );

  keycloak-health = pkgs.writeShellScriptBin "keycloak-health" ''
    ${pkgs.curl}/bin/curl -k --head -fsS "https://localhost:${toString cfg.settings.http-management-port}${lib.removeSuffix "/" cfg.settings.http-management-relative-path}/health/ready"
  '';

  keycloakEnv = {
    KC_HOME_DIR = cfg.dataDir + "/keycloak";
    KC_CONF_DIR = cfg.dataDir + "/keycloak/conf";
    KC_TMP_DIR = cfg.dataDir + "/keycloak/tmp";

    KC_BOOTSTRAP_ADMIN_USERNAME = "admin";
    KC_BOOTSTRAP_ADMIN_PASSWORD = "${lib.escapeShellArg cfg.initialAdminPassword}";
  };

  keycloak-start =
    pkgs.writeShellScriptBin "keycloak-start"
      # Bash
      ''
        set -euo pipefail
        mkdir -p "$KC_HOME_DIR"
        mkdir -p "$KC_HOME_DIR/conf"
        mkdir -p "$KC_HOME_DIR/tmp"

        # Always remove the symlinks for the realm imports.
        rm -rf "$KC_HOME_DIR/data/import" || true
        mkdir -p "$KC_HOME_DIR/data/import"

        ln -fs ${keycloakBuild}/providers "$KC_HOME_DIR/"
        ln -fs ${keycloakBuild}/lib "$KC_HOME_DIR/"
        install -D -m 0600 ${confFile} "$KC_HOME_DIR/conf/keycloak.conf"

        echo "Keycloak config:"
        ${keycloakBuild}/bin/kc.sh show-config || true

        echo "Import realms (if any)..."
        ${builtins.concatStringsSep "\n" realmImport}
        echo "========================"

        echo "Start keycloak:"
        exec ${keycloakBuild}/bin/kc.sh start --optimized --import-realm
      '';
in
{
  # Merge some default values into the freeform options.
  settings = lib.mapAttrs (n: v: lib.mkOptionDefault v) {
    # We always enable http since we also use it to check the health.
    http-enabled = true;
    db = cfg.database.type;

    health-enabled = true;
    http-management-relative-path = "/";

    log-console-level = "info";
    log-level = "info";

    https-certificate-file =
      if providedSSLCerts then cfg.sslCertificate else "${dummyCertificates}/ssl-cert.crt";
    https-certificate-key-file =
      if providedSSLCerts then cfg.sslCertificateKey else "${dummyCertificates}/ssl-cert.key";
  };

  outputs = {
    settings.processes = {
      ${name} = {
        environment = keycloakEnv;
        command = "${lib.getExe keycloak-start}";
        readiness_probe = {
          exec = {
            command = "${lib.getExe keycloak-health}";
          };
          initial_delay_seconds = 10;
          timeout_seconds = 4;
          failure_threshold = 20;
        };
      };

      "${name}-realm-export" = lib.mkIf cfg.scripts.exportRealm {
        environment = keycloakEnv;
        command = "${keycloak-realm-export}/bin/keycloak-realm-export";
        disabled = true;
        description = ''
          Export a realm '$1' (first argument) from keycloak to location '$2' (second argument).
        '';
      };

      # Export all configured realms.
      "${name}-realm-export-all" = lib.mkIf (realmsExport != [ ]) {
        environment = keycloakEnv;
        command = "${keycloak-realm-export-all}/bin/keycloak-realm-export-all";
        disabled = true;
        description = ''
          Save the configured realms from keycloak, to back them up. You can run it manually.
        '';
      };
    };
  };
}
