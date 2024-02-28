# pgAdmin

[pgAdmin] is a feature rich Open Source administration and development platform for PostgreSQL.

[pgAdmin]: https://github.com/prometheus/prometheus

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
