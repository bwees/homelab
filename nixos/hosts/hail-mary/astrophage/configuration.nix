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
    # by-id: the ZFS disks are also sd*, and kernel names can reorder across boots
    device = "/dev/disk/by-id/ata-NGFF_2280_256GB_SSD_20240926113198";
    layout = "lvm";
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
