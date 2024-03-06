(final: prev: {
  grafana = (prev.callPackage "${prev.path}/pkgs/servers/monitoring/grafana" {
    buildGoModule = args: prev.buildGoModule (args // {

      vendorHash = "sha256-Ig7Vj3HzMVOjT6Tn8aS4W000uKGoPOCFh2yIfyEWn78=";

      proxyVendor = true;

      offlineCache = args.offlineCache.overrideAttrs (oa: {
        buildPhase = final.lib.replaceStrings
          [ "yarn config set --json supportedArchitectures.os '[ \"linux\" ]'" ]
          [ "yarn config set --json supportedArchitectures.os '[ \"linux\", \"darwin\" ]'" ]
          oa.buildPhase;
        outputHash = "sha256-pqInPfZEg2tcp8BXg1nnMddRZ1yyZ6KQa2flWd4IZSU=";
      });

      # exclude the package instead of `rm pkg/util/xorm/go.{mod,sum}`
      # turns out, only removing the files is not enough, fails with:
      # > pkg/services/sqlstore/migrator/dialect.go:9:2: module ./pkg/util/xorm: reading pkg/util/xorm/go.mod: open /build/source/pkg/util/xorm/go.mod: no such file or directory

      # both excluding and removing (`go.mod`) is also not an option because excludedPackages expects a `go.mod`
      excludedPackages = args.excludedPackages ++ [ "xorm" ];

      postConfigure = final.lib.replaceStrings [ "rm pkg/util/xorm/go.{mod,sum}" ] [ "" ] args.postConfigure;
    });
  });
})
