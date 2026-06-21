{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../lib/base-packages.nix
    ../../lib/bwees.nix
    ../../lib/garbage-collect.nix
    ../../lib/root-ca.nix
    ../../lib/tailscale.nix
    ../../lib/k3s.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "tau-ceti";
  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
    "--accept-routes"
  ];

  services.fail2ban.enable = true;
}
