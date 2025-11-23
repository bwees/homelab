{
  config,
  lib,
  pkgs,
  ...
}:

{
  users.users.bwees.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGvk7TXY9IsggrlVgLLWp6tInTXFdBsgfARKJzh8HB++"
  ];
}
