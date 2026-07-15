{
  writeShellApplication,
  process-compose,
  jq,
  # Own stuff.
  keycloak-name,
  realmDstDir,
  pcSocketPath,
  ...
}:

writeShellApplication {
  name = "test-export";

  runtimeInputs = [
    process-compose
    jq
  ];

  text =
    # Bash
    ''
      export PC_SOCKET_PATH="${pcSocketPath}"

      # Silence process-compose not finding a config home.
      mkdir -p "$(pwd)/.config/process-compose"
      # shellcheck disable=SC2155
      export XDG_CONFIG_HOME="$(pwd)/.config"

      test_export() {
        echo "Stop keycloak..."
        process-compose process stop "${keycloak-name}" -u "$PC_SOCKET_PATH"

        for _ in $(seq 1 10); do
          if
            [ "$(
              process-compose process get "${keycloak-name}"  -o json -u "$PC_SOCKET_PATH" |
                jq -r ".[0].status"
            )" = "Completed" ]
          then
            completed="true"
            break
          fi

          sleep 2
        done

        echo "Export realms..."
        process-compose  process start "${keycloak-name}-realm-export-all" -u "$PC_SOCKET_PATH"

        completed="false"
        for _ in $(seq 1 30); do
          if
            [ "$(
              process-compose  process get "${keycloak-name}-realm-export-all"  \
                -o json -u "$PC_SOCKET_PATH" |
                jq -r ".[0].status"
            )" = "Completed" ]
          then
            completed="true"
            break
          fi

          sleep 2
        done

        if [ "$completed" != "true" ]; then
          echo "!! Realm export did not complete in time."
          return 1
        fi

        if [ ! -f "${realmDstDir}/master.json" ]; then
          echo "!! Realm '${realmDstDir}/master.json' did not get exported."
          return 1
        fi

        if [ ! -f "${realmDstDir}/test.json" ]; then
          echo "!! Realm '${realmDstDir}/test.json'  did not get exported".
        fi
      }

      test_export
    '';
}
