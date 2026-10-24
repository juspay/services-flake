{
  pkgs,
  lib,
  config,
  ...
}:
{
  # A single-instance custom service, as described in
  # https://community.flake.parts/services-flake/custom-service#single-instance
  options.services.hello = {
    enable = lib.mkEnableOption "Enable hello service";
    package = lib.mkPackageOption pkgs "hello" { };
  };

  config = {
    services.hello.enable = true;
    services.redis."r1".enable = true;

    settings.processes.test = {
      command = pkgs.writeShellApplication {
        name = "devshell-test";
        runtimeInputs = config.services.outputs.devShell.nativeBuildInputs;
        text = ''
          hello
          redis-cli --version
        '';
      };
      depends_on."r1".condition = "process_healthy";
    };
  };
}
