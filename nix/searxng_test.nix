{ pkgs, ... }:
{
  services.searxng."searxng1" = {
    enable = true;
    use_default_settings = false;
    settings = {
      server.secret_key = "secret";
      doi_resolvers."dummy" = "http://example.org";
      default_doi_resolver = "dummy";
    };
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      runtimeInputs = [ pkgs.curl ];
      text = ''
        curl http://127.0.0.1:8080
      '';
      name = "searxng-test";
    };
    depends_on."searxng1".condition = "process_healthy";
  };
}
