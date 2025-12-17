{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../lib/base_packages.nix
    ../../lib/bwees.nix
    ../../lib/docker.nix
    ../../lib/garbage_collect.nix
    ../../lib/root_ca.nix
    ../../lib/tailscale.nix
  ];

  system.stateVersion = "25.05"; # Did you read the comment?

  # Networking/Clock
  networking.hostName = "homelab-vps";
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.ip = "100.105.77.106";
  services.tailscale.extraUpFlags = [
    "--advertise-exit-node"
    "--accept-routes"
  ];
}
