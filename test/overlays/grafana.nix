(final: prev: {
  # Because tests are failing on darwin: https://github.com/juspay/services-flake/pull/115#issuecomment-1970467684
  pgadmin4 = prev.pgadmin4.overrideAttrs (_: { doInstallCheck = false; });
  grafana =
    let
      skipTest = lineOffset: testCase: file:
        let
          jumpAndAppend = final.lib.concatStringsSep ";" (final.lib.replicate (lineOffset - 1) "n" ++ [ "a" ]);
        in
        ''
          sed -i -e '/${testCase}/{
          ${jumpAndAppend} t.Skip();
          }' ${file}
        '';
    in
    (prev.callPackage "${prev.path}/pkgs/servers/monitoring/grafana" {
      buildGoModule = args: prev.buildGoModule (args // {
        vendorHash = "sha256-Ig7Vj3HzMVOjT6Tn8aS4W000uKGoPOCFh2yIfyEWn78=";
        proxyVendor = true;
        offlineCache = args.offlineCache.overrideAttrs (_: {
          buildPhase = ''
            runHook preBuild
            export HOME="$(mktemp -d)"
            yarn config set enableTelemetry 0
            yarn config set cacheFolder $out
            yarn config set --json supportedArchitectures.os '[ "linux", "darwin" ]'
            yarn config set --json supportedArchitectures.cpu '["arm", "arm64", "ia32", "x64"]'
            yarn
            runHook postBuild
          '';
          outputHash = "sha256-pqInPfZEg2tcp8BXg1nnMddRZ1yyZ6KQa2flWd4IZSU=";
        });

        # exclude the package instead of `rm pkg/util/xorm/go.{mod,sum}`
        # turns out, only removing the files is not enough, fails with:
        # > pkg/services/sqlstore/migrator/dialect.go:9:2: module ./pkg/util/xorm: reading pkg/util/xorm/go.mod: open /build/source/pkg/util/xorm/go.mod: no such file or directory

        # both excluding and removing (`go.mod`) is also not an option because excludedPackages expects a `go.mod`
        excludedPackages = args.excludedPackages ++ [ "xorm" ];

        postConfigure = ''
          # Generate DI code that's required to compile the package.
          # From https://github.com/grafana/grafana/blob/v8.2.3/Makefile#L33-L35
          wire gen -tags oss ./pkg/server
          wire gen -tags oss ./pkg/cmd/grafana-cli/runner

          GOARCH= CGO_ENABLED=0 go generate ./pkg/plugins/plugindef
          GOARCH= CGO_ENABLED=0 go generate ./kinds/gen.go
          GOARCH= CGO_ENABLED=0 go generate ./public/app/plugins/gen.go
          GOARCH= CGO_ENABLED=0 go generate ./pkg/kindsys/report.go

          # The testcase makes an API call against grafana.com:
          #
          # [...]
          # grafana> t=2021-12-02T14:24:58+0000 lvl=dbug msg="Failed to get latest.json repo from github.com" logger=update.checker error="Get \"https://raw.githubusercontent.com/grafana/grafana/main/latest.json\": dial tcp: lookup raw.githubusercontent.com on [::1]:53: read udp [::1]:36391->[::1]:53: read: connection refused"
          # grafana> t=2021-12-02T14:24:58+0000 lvl=dbug msg="Failed to get plugins repo from grafana.com" logger=plugin.manager error="Get \"https://grafana.com/api/plugins/versioncheck?slugIn=&grafanaVersion=\": dial tcp: lookup grafana.com on [::1]:53: read udp [::1]:41796->[::1]:53: read: connection refused"
          ${skipTest 1 "Request is not forbidden if from an admin" "pkg/tests/api/plugins/api_plugins_test.go"}

          # Skip a flaky test (https://github.com/NixOS/nixpkgs/pull/126928#issuecomment-861424128)
          ${skipTest 2 "it should change folder successfully and return correct result" "pkg/services/libraryelements/libraryelements_patch_test.go"}

          # Skip flaky tests (https://logs.ofborg.org/?key=nixos/nixpkgs.263185&attempt_id=5b056a17-67a7-4b74-9dc7-888eb1d6c2dd)
          ${skipTest 1 "TestIntegrationRulerAccess" "pkg/tests/api/alerting/api_alertmanager_test.go"}
          ${skipTest 1 "TestIntegrationRulePause" "pkg/tests/api/alerting/api_ruler_test.go"}

          # Requires making API calls against storage.googleapis.com:
          #
          # [...]
          # grafana> 2023/08/24 08:30:23 failed to copy objects, err: Post "https://storage.googleapis.com/upload/storage/v1/b/grafana-testing-repo/o?alt=json&name=test-path%2Fbuild%2FTestCopyLocalDir2194093976%2F001%2Ffile2.txt&prettyPrint=false&projection=full&uploadType=multipart": dial tcp: lookup storage.googleapis.com on [::1]:53: read udp [::1]:36436->[::1]:53: read: connection refused
          # grafana> panic: test timed out after 10m0s
          rm pkg/build/gcloud/storage/gsutil_test.go

          # Setup node_modules
          export HOME="$(mktemp -d)"

          # Help node-gyp find Node.js headers
          # (see https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/javascript.section.md#pitfalls-javascript-yarn2nix-pitfalls)
          mkdir -p $HOME/.node-gyp/${final.nodejs.version}
          echo 9 > $HOME/.node-gyp/${final.nodejs.version}/installVersion
          ln -sfv ${final.nodejs}/include $HOME/.node-gyp/${final.nodejs.version}
          export npm_config_nodedir=${final.nodejs}

          yarn config set enableTelemetry 0
          yarn config set cacheFolder $offlineCache
          yarn --immutable-cache

          # The build OOMs on memory constrained aarch64 without this
          export NODE_OPTIONS=--max_old_space_size=4096
        '';
      });
    });
})