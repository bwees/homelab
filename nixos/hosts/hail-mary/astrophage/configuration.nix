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

  services.beszel.agent.enable = true;
  services.beszel.agent.environment = {
    "KEY" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKL+/R5W0b6x/4/bbbcNr/k2yQ96MIbXesRDWxgXWQtD";
  };

  services.k3s.serverAddr = "https://192.168.50.110:6443";
  services.k3s.extraFlags = [
    "--node-taint=dedicated=storage:NoSchedule"
    "--node-label=lab.bwees/role=nas"
  ];
}
