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
    ./storage.nix
    ./shares.nix
    ./backups.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "homelab-nas";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.ip = "100.80.89.123";
  services.tailscale.extraSetFlags = [ ];

  # for zfs
  networking.hostId = "9806791d";

  # Users
  users.users.bwees.uid = 3000;
  users.users.homelab = {
    isNormalUser = true;
    createHome = false;
  };
}
