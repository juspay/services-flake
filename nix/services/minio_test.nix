{ pkgs, ... }:
{
  services.minio."minio1".enable = true;

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      runtimeInputs = [ pkgs.curl ];
      text = ''
        curl http://127.0.0.1:9000/minio/health/live
      '';
      name = "minio-test";
    };
    depends_on."minio1".condition = "process_healthy";
  };
}
