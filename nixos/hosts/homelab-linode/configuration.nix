{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../lib/base_packages.nix
    ../../lib/bwees.nix
    ../../lib/docker.nix
    ../../lib/garbage_collect.nix
    ../../lib/root_ca.nix
    ../../lib/tailscale.nix
    ../../lib/build_receiver.nix
  ];

  system.stateVersion = "25.05"; # Did you read the comment?

  # Networking/Clock
  networking.hostName = "homelab-linode";
  services.tailscale.ip = "100.109.20.66";
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
}
