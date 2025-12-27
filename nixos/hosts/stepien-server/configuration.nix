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
    ../../lib/storage-backup.nix
    ../../lib/tailscale.nix
  ];

  system.stateVersion = "25.11";

  # Networking/Clock
  networking.hostName = "stepien-server";
  time.timeZone = "America/New_York";

  # Prefer IPv4 over IPv6 due to IPv6 issues with ISP
  networking.enableIPv6 = false;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.ip = "100.81.233.29";
  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
  ];
}
