# pgAdmin

[pgAdmin] is a feature rich Open Source administration and development platform for PostgreSQL.

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
