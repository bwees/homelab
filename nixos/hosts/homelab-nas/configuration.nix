{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../lib/base-packages.nix
    ../../lib/bwees.nix
    ../../lib/docker.nix
    ../../lib/garbage-collect.nix
    ../../lib/root-ca.nix
    ../../lib/tailscale.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "homelab-nas";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.ip = "100.65.90.4";
  services.tailscale.extraSetFlags = [ "--advertise-exit-node" ];
}
