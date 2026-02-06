{ pkgs
, config
, ...
}: {
  services.elasticmq."elasticmq1" = {
    enable = true;
  };

  settings.processes.test =
    let
      inherit (config.services.elasticmq."elasticmq1".restSqs) bindHost bindPort;
    in
    {
      command = pkgs.writeShellApplication {
        name = "elasticmq-test";
        runtimeInputs = with pkgs; [ awscli2 jq ];
        runtimeEnv = {
          AWS_ACCESS_KEY_ID = "fake";
          AWS_SECRET_ACCESS_KEY = "fake";
          AWS_DEFAULT_REGION = "us-east-1";
        };
        text = ''
          aws sqs list-queues --endpoint-url "http://${bindHost}:${toString bindPort}" \
          | jq '.QueueUrls'
        '';
      };
      depends_on."elasticmq1".condition = "process_healthy";
    };
}
