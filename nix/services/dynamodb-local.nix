{ pkgs, lib, name, config, ... }: {
  options = {
    package = lib.mkPackageOption pkgs "dynamodb-local" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = ''
        The port number that DynamoDB uses to communicate with your application.
      '';
    };

    dbPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The directory where DynamoDB writes its database file. If you don't specify this option, the file
        is written to the current directory.
      '';
    };

    inMemory = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        DynamoDB runs in memory instead of using a database file. When you stop DynamoDB, none of the
        data is saved.
      '';
      apply = v:
        lib.throwIf (config.dbPath != null) ''
          You can't specify both -dbPath and -inMemory at once.
        ''
          v;
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra args to pass down to DynamoDB.
      '';
    };

    disableTelemetry = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Specify if DynamoDB local should send telemetry.
      '';
    };
  };

  config.outputs.settings.processes.${name} =
    let
      startCommand = pkgs.writeShellApplication {
        name = "start-dynamodb";
        runtimeInputs = [ config.package ];
        text = ''
          ${lib.optionalString (config.dbPath != null) ''
            mkdir -p ${config.dbPath}
          ''}
           exec dynamodb-local \
             -port ${toString config.port} \
             ${lib.optionalString (config.dbPath != null) "-dbPath ${config.dbPath}"} \
             ${lib.optionalString config.inMemory "-inMemory"} \
             ${lib.optionalString config.disableTelemetry "-disableTelemetry"} \
             ${lib.escapeShellArgs config.extraArgs}
        '';
      };
    in
    {
      command = startCommand;
      readiness_probe = {
        # There is no explicit healthcheck in DynamoDB. Instead, it's a common practice to
        # use `list-tables` opearation as a healthcheck. Inspired by Localstack and devenv
        # DynamoDB service.
        # DynamoDB Local doesn't have any credentials, but awscli expects them.
        exec.command = ''
          AWS_ACCESS_KEY_ID='fake' \
          AWS_SECRET_ACCESS_KEY='fake' \
          AWS_DEFAULT_REGION='us-east-1' \
          ${lib.getExe pkgs.awscli2} dynamodb list-tables \
            --endpoint-url http://127.0.0.1:${toString config.port}
        '';
        initial_delay_seconds = 2;
        period_seconds = 10;
        timeout_seconds = 4;
        success_threshold = 1;
        failure_threshold = 5;
      };
      # https://github.com/F1bonacc1/process-compose#-auto-restart-if-not-healthy
      availability = {
        restart = "on_failure";
        max_restarts = 5;
      };
    };
}
