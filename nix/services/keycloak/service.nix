{
  config,
  lib,
  pkgs,
  name,
  ...
}:
let
  cfg = config;

  # Renders the Keycloak configuration file (`keycloak.conf`).
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
        else
          throw "unsupported type ${builtins.typeOf v}: ${(lib.generators.toPretty { }) v}";
    };
  };

  # Filter out empty values.
  filteredConfig = lib.converge (lib.filterAttrsRecursive (
    _: v:
    !builtins.elem v [
      { }
      null
    ]
  )) cfg.settings;

  # Write the Keycloak config file.
  confFile = pkgs.writeText "keycloak.conf" (keycloakConfig filteredConfig);

  # Build the Keycloak derivation with the rendered config and the plugins.
  keycloakBuild = (
    cfg.package.override {
      inherit confFile;

      plugins = cfg.package.enabledPlugins ++ cfg.plugins;
    }
  );

  # Self-signed certificate used when the user does not provide one.
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

  providedSSLCerts =
    assert lib.assertMsg (
      (cfg.sslCertificate == null) == (cfg.sslCertificateKey == null)
    ) "Both `sslCertificate` and `sslCertificateKey` must be set together, or neither. Got only one.";
    cfg.sslCertificate != null && cfg.sslCertificateKey != null;

  # Generate the command to import realms.
  realmImport = lib.mapAttrsToList (
    realm: e:
    let
      f = e.import;
    in
    # Bash
    ''
      f=$(realpath "${f}")
      echo "Symlinking realm file '$f' to import path '$KC_HOME_DIR/data/import'."
      if [ ! -f "$f" ]; then
        echo "Realm file '$f' does not exist!" >&2
        exit 1
      fi
      ln -fs "$f" "$KC_HOME_DIR/data/import/"
      unset f
    ''
  ) (lib.filterAttrs (_: v: v.import != null) cfg.realms);

  # Generate the commands to export realms.
  assertKeycloakStopped = [
    ''
      if ${keycloak-health}/bin/keycloak-health &>/dev/null; then
        echo "Keycloak is still running: stop it first, then run this command again." >&2
        exit 1
      fi

      # Ensure the KC_HOME_DIR is set up for the export command.
      mkdir -p "$KC_HOME_DIR/conf"
      ln -fs ${keycloakBuild}/providers "$KC_HOME_DIR/"
      ln -fs ${keycloakBuild}/lib "$KC_HOME_DIR/"
      install -D -m 0600 ${confFile} "$KC_HOME_DIR/conf/keycloak.conf"
    ''
  ];

  realmExportPath =
    let
      isInStore =
        x:
        lib.path.hasStorePathPrefix (
          if builtins.isPath x then x else /. + builtins.unsafeDiscardStringContext x
        );
    in
    realm: e:
    if e.export.path != null then
      e.export.path
    else
      (
        if e.import == null || isInStore e.import then
          (config.dataDir + "/realm-export/${realm}.json")
        else
          e.import
      );

  realmsToExport = lib.filterAttrs (_: v: v.export.enable) cfg.realms;
  realmsExport =
    if (!cfg.exportRealms || lib.length (lib.attrNames realmsToExport) == 0) then
      [ ]
    else
      assertKeycloakStopped
      ++ lib.mapAttrsToList (
        realm: e:
        let
          file = realmExportPath realm e;
        in
        # Bash
        ''
          echo "Exporting realm '${realm}' to '${file}'."
          mkdir -p "$(dirname "${file}")"
          ${keycloakBuild}/bin/kc.sh export --optimized --realm "${realm}" --file "${file}"

          echo "Beautifying realm export '${file}' for diffing."
          temp_file=$(${pkgs.coreutils}/bin/mktemp)
          ${pkgs.jq}/bin/jq --sort-keys . "${file}" > "$temp_file"
          ${pkgs.coreutils}/bin/mv "$temp_file" "${file}"
        ''
      ) realmsToExport;

  keycloak-realm-export-all = pkgs.writeShellScriptBin "keycloak-realm-export-all" (
    lib.concatStringsSep "\n" realmsExport
  );

  keycloak-health = pkgs.writeShellScriptBin "keycloak-health" ''
    ${pkgs.curl}/bin/curl -k --head -fsS "https://localhost:${toString cfg.settings.http-management-port}${lib.removeSuffix "/" cfg.settings.http-management-relative-path}/health/ready"
  '';

  keycloakEnv = {
    # Note: we prefix with "./" because Keycloak's database URL
    # does not accept implicitly relative paths.
    KC_HOME_DIR = "./" + cfg.dataDir;
    KC_CONF_DIR = cfg.dataDir + "/conf";
    KC_TMP_DIR = cfg.dataDir + "/tmp";

    KC_BOOTSTRAP_ADMIN_USERNAME = cfg.initialAdminUsername;
    KC_BOOTSTRAP_ADMIN_PASSWORD = cfg.initialAdminPassword;
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

        echo "Importing realms (if any)..."
        ${builtins.concatStringsSep "\n" realmImport}
        echo "========================"

        echo "Starting Keycloak:"
        exec ${keycloakBuild}/bin/kc.sh start --optimized --import-realm
      '';
in
{
  # Merge some default values into the freeform options.
  settings = lib.mapAttrs (n: v: lib.mkOptionDefault v) {
    # HTTP stays enabled so that the service is reachable without TLS;
    # the health check itself goes through the HTTPS management interface.
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
        command = keycloak-start;
        readiness_probe = {
          exec = {
            command = "${lib.getExe keycloak-health}";
          };
          initial_delay_seconds = 10;
          timeout_seconds = 4;
          failure_threshold = 20;
        };
      };

    }
    // (lib.optionalAttrs (realmsExport != [ ]) {
      # Export all configured realms.
      "${name}-realm-export-all" = {
        environment = keycloakEnv;
        command = keycloak-realm-export-all;
        disabled = true;
        description = ''
          Export the configured realms from Keycloak, e.g. to back them up.
          Run it manually once Keycloak has been stopped.
        '';
      };
    });
  };
}
