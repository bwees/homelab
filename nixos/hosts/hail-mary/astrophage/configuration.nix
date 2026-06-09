{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../../lib/base-packages.nix
    ../../../lib/k3s.nix
    ../../../lib/bwees.nix
    ../../../lib/garbage-collect.nix
    ../../../lib/root-ca.nix
    ../../../lib/tailscale.nix
    ./storage.nix
    ./shares.nix
    ./backups.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "astrophage";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.extraUpFlags = [ 
    "--advertise-tags=tag:hail-mary,tag:k3s"
  ];

  # for zfs
  networking.hostId = "9806791d";

  # Users
  users.users.bwees.uid = 3000;
  users.users.homelab = {
    isNormalUser = true;
    createHome = false;
  };
}
