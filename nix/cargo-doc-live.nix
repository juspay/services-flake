{ pkgs, lib, name, config, ... }:
let
  inherit (lib) types;
in
{
  options = {
    enable = lib.mkEnableOption name;

    projectRoot = lib.mkOption {
      type = types.path;
      description = "Path to the cargo project root";
      default = ./.;
    };

    port = lib.mkOption {
      type = types.port;
      description = "The port for 'cargo doc'";
      default = 8008;
    };

    crateName = lib.mkOption {
      type = types.str;
      description = "The crate to use when opening docs in browser";
      default = builtins.replaceStrings [ "-" ] [ "_" ]
        ((lib.trivial.importTOML "${config.projectRoot}/Cargo.toml").package.name);
      defaultText = "The crate name is derived from the Cargo.toml file";
    };

    outputs.settings = lib.mkOption {
      type = types.deferredModule;
      internal = true;
      readOnly = true;
      default = {
        processes = {
          "${name}-cargo-doc" = {
            command = pkgs.writeShellApplication {
              name = "cargo-doc";
              runtimeInputs = with pkgs; [ cargo cargo-watch nodePackages.browser-sync ];
              text =
                ''
                  run-cargo-doc() {
                    cargo doc --document-private-items --all-features
                    browser-sync reload --port ${toString config.port}  # Trigger reload in browser
                  }; export -f run-cargo-doc
                  cargo-watch watch -s run-cargo-doc
                '';
            };
            readiness_probe = {
              period_seconds = 1;
              failure_threshold = 100000; # 'cargo doc' can take quite a while.
              exec.command = ''
                # Wait for the first 'cargo doc' to have completed.
                # We'll use this state to block browser-sync from starting
                # and opening the URL in the browser.
                ls target/doc/${config.crateName}/index.html
              '';
            };
            namespace = name;
            availability.restart = "on_failure";
          };
          "${name}-browser-sync" = {
            command = pkgs.writeShellApplication {
              name = "browser-sync";
              runtimeInputs = [ pkgs.nodePackages.browser-sync ];
              text =
                ''
                  browser-sync start --port ${toString config.port} --ss target/doc -s target/doc \
                  --startPath /${config.crateName}/
                '';
            };
            namespace = name;
            depends_on."${name}-cargo-doc".condition = "process_healthy";
          };
        };
      };
    };
  };
}