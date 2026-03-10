{ pkgs
, config
, ...
}: {
  services.dynamodb-local."dynamodb1" = {
    enable = true;
    inMemory = true;
  };

  services.dynamodb-local."dynamodb2" = {
    enable = true;
    port = 8001;
    dbPath = "/tmp/dynamodb2";
  };

  settings.processes.test =
    let
      cfg1 = config.services.dynamodb-local."dynamodb1";
      cfg2 = config.services.dynamodb-local."dynamodb2";
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
          aws dynamodb list-tables --endpoint-url "http://127.0.0.1:${toString cfg1.port}" \
          | jq '.TableNames'
          aws dynamodb list-tables --endpoint-url "http://127.0.0.1:${toString cfg2.port}" \
          | jq '.TableNames'
        '';
      };
      depends_on."dynamodb1".condition = "process_healthy";
      depends_on."dynamodb2".condition = "process_healthy";
    };
}
