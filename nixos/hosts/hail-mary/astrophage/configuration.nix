{
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../../lib/beszel-intel-gpu.nix
    ./storage.nix
    ./shares.nix
    ./backups.nix
  ];

  system.stateVersion = "25.05";

  networking.hostName = "astrophage";

  homelab.disk = {
    device = "/dev/sda";
    flatRoot = true;
  };
  boot.loader.grub.devices = lib.mkForce [ "nodev" ];

  # for zfs
  networking.hostId = "9806791d";

  users.users.bwees.uid = 3000;

  services.k3s.extraFlags = [
    "--node-label=lab.bwees/role=nas"
  ];
}
