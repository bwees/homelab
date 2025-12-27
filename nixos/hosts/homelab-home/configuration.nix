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
    ../../lib/storage_backup.nix
    ../../lib/tailscale.nix
  ];

  system.stateVersion = "25.11";

  # Networking/Clock
  networking.hostName = "homelab-home";
  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.ip = "100.101.55.71";
  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
    "--advertise-routes=10.0.1.0/24"
  ];
}
