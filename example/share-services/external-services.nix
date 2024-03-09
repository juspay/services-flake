{
  services.postgres."pg1" = {
    enable = true;
    listen_addresses = "127.0.0.1";
  };

  services.redis."r1".enable = true;
}
