{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../../lib/base-packages.nix
    ../../../lib/bwees.nix
    ../../../lib/k3s.nix
    ../../../lib/garbage-collect.nix
    ../../../lib/storage-backup.nix
    ../../../lib/tailscale.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "grace";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.tailscale.extraUpFlags = [ 
    "--advertise-exit-node"
    "--advertise-tags=tag:hail-mary"
  ];

  services.beszel.agent.enable = true;
  services.beszel.agent.environment = {
    "KEY" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKL+/R5W0b6x/4/bbbcNr/k2yQ96MIbXesRDWxgXWQtD";
  };
}
