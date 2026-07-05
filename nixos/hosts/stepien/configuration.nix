{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../lib/base-packages.nix
    ../../lib/beszel.nix
    ../../lib/bwees.nix
    ../../lib/garbage-collect.nix
    ../../lib/root-ca.nix
    ../../lib/storage-backup.nix
    ../../lib/tailscale.nix
    ../../lib/k3s.nix
  ];

  system.stateVersion = "25.11";

  # Networking/Clock
  networking.hostName = "stepien";
  time.timeZone = "America/New_York";

  # Prefer IPv4 over IPv6 due to IPv6 issues with ISP
  networking.enableIPv6 = false;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
  ];

  services.k3s.extraFlags = [
    "--node-label=node.longhorn.io/create-default-disk=true"
  ];
}
