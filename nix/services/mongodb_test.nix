{ pkgs, config, ... }:
{
  services.mongodb."mongo1".enable = true;

  settings.processes.test =
    let
      cfg = config.services.mongodb."mongo1";
    in
    {
      command = pkgs.writeShellApplication {
        runtimeInputs = [
          cfg.package
          pkgs.mongosh
        ];
        text = ''
          mongosh --username default --password password mongodb://127.0.0.1/ --authenticationDatabase admin
        '';
        name = "mongo-test";
      };
      depends_on."mongo1-configure".condition = "process_completed_successfully";
    };
}
