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

  system.stateVersion = "25.11";

  # Networking/Clock
  networking.hostName = "wolf";
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  # disable firewall
  networking.firewall.enable = false;
}
