{ pkgs, ... }: {
  services.open-webui."open-webui1" = {
    enable = true;
    environment = {
      # Requires network connection
      RAG_EMBEDDING_MODEL = "";
    };
  };

  settings.processes.test = {
    command = pkgs.writeShellApplication {
      runtimeInputs = [ pkgs.curl ];
      text = ''
        # Avoid printing the entire HTML page on the stdout, we just want to know if the page is active.
        curl http://127.0.0.1:1111 > /dev/null
      '';
      name = "open-webui-test";
    };
    depends_on."open-webui1".condition = "process_healthy";
  };
}
