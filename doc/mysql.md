# MySQL

[MySQL](https://github.com/mysql/mysql-server) is a popular open-source relational database management system (RDBMS).

{#start}

## Getting started

```nix
# In `perSystem.process-compose.<name>`
{
  services.mysql."mysql1".enable = true;
}
```

{#tips}

## Tips & Tricks

{#port}

### Use a different port

```nix
{
  services.mysql."mysql1" = {
    enable = true;
    settings.mysqld.port = 3307;
  };
}
```

{#schema}

### Multiple `.sql` files for schema

The `schema` can be a path to a single `.sql` file or a directory containing multiple `.sql` files.

```nix
{
  services.mysql."mysql1" = {
    enable = true;
    initialDatabases = [{ name = "test_database"; schema = ./test_schemas; }];
  };
}
```
