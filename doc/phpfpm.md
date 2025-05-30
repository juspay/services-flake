# PHP FastCGI Process Manager

[PHP FPM](https://www.php.net/manual/en/book.fpm.php) (FastCGI Process Manager) is a primary PHP FastCGI implementation containing some features (mostly) useful for heavy-loaded sites.

## Unix socket

PHP FPM supports the usage of [Unix socket](https://man7.org/linux/man-pages/man2/socket.2.html) to listen to connections. By default, the socket `phpfpm.sock` will be used.

```nix
# Inside `process-compose.<name>`
{
  services.phpfpm."php1" = {
    enable = true;
    extraConfig = {
      "pm" = "ondemand";
      "pm.max_children" = 1;
    };
  };
}
```

## TCP port

```nix
# Inside `process-compose.<name>`
{
  services.phpfpm."php1" = {
    enable = true;
    listen = 9000;
    extraConfig = {
      "pm" = "ondemand";
      "pm.max_children" = 1;
    };
  };
}
```

## Usage example

<https://github.com/juspay/services-flake/blob/main/nix/services/phpfpm_test.nix>
