# pgAdmin

[pgAdmin] is a feature rich Open Source administration and development platform for #[[postgresql]].

[pgAdmin]: https://www.pgadmin.org/

## Getting Started

```nix
# In `perSystem.process-compose.<name>`
{
  services.pgadmin."pgad1" = {
    enable = true;
    initialEmail = "email@gmail.com";
    initialPassword = "password";
  };
}
```

## Guide

### Visualize system statistics

`pgAdmin` uses the functions exposed by [system_stats](https://github.com/EnterpriseDB/system_stats) [[postgresql]] extension to monitor the system metrics such as CPU, memory and disk information. Use this in your config:

```nix
# In `perSystem.process-compose.<name>`
{
  services.postgres."pg1" = {
    enable = true;
    extensions = exts: [
      exts.system_stats
    ];
    # This creates the extensions for the `postgres` database, if you need it for a custom database,
    # ensure to add the below script in `schemas` of the database of your choice under `initialDatabses`.
    initialScript.before = ''
      CREATE EXTENSION system_stats;
    '';
  };
  services.pgadmin."pgad1" = {
    enable = true;
    initialEmail = "email@gmail.com";
    initialPassword = "password";
  };
}
```

Open the pgAdmin dashboard, establish a connection with your database and you will see:
![[pgadmin-system-stats.png]]
