{ pkgs, config, ... }: {
  services.qdrant."qdrant1" = {
    enable = true;
  };
  settings.processes.qdrant1.environment = {
    # ERROR qdrant::startup: Panic occurred in file src/common/inference/service.rs at line 104:
    # Invalid timeout value for HTTP client:
    # reqwest::Error { kind: Builder, source: General("No CA certificates were loaded from the system") }
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };

  settings.processes.test =
    let
      cfg = config.services.qdrant."qdrant1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "qdrant-test";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          curl -f http://${cfg.host}:${toString cfg.httpPort}/healthz
          curl -f http://${cfg.host}:${toString cfg.httpPort}/collections
        '';
      };
      depends_on."qdrant1".condition = "process_healthy";
    };
}
