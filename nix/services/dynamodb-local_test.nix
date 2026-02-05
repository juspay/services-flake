{ pkgs
, config
, ...
}: {
  services.dynamodb-local."dynamodb1" = {
    enable = true;
    inMemory = true;
  };

  settings.processes.test =
    let
      cfg = config.services.dynamodb-local."dynamodb1";
    in
    {
      command = pkgs.writeShellApplication {
        name = "dynamodb-test";
        runtimeInputs = with pkgs; [ awscli2 jq ];
        runtimeEnv = {
          AWS_ACCESS_KEY_ID = "fake";
          AWS_SECRET_ACCESS_KEY = "fake";
          AWS_DEFAULT_REGION = "us-east-1";
        };
        text = ''
          aws dynamodb list-tables --endpoint-url "http://127.0.0.1:${toString cfg.port}" \
          | jq '.TableNames'
        '';
      };
      depends_on."dynamodb1".condition = "process_healthy";
    };
}
