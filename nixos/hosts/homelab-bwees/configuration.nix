{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../lib/base_packages.nix
    ../../lib/bwees.nix
    ../../lib/sanoid.nix
    ../../lib/tailscale.nix
    ../../lib/zfs_backup.nix
    ../../lib/root_ca.nix
    ../../lib/garbage_collect.nix
  ];

  system.stateVersion = "25.05";

  # Boot Options
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  systemd.enableEmergencyMode = false;

  # Networking/Clock
  networking.hostName = "homelab-bwees";
  networking.networkmanager.enable = true;
  networking.hostId = "a183a60c"; # needed for zfs
  time.timeZone = "America/Chicago";
  services.openssh.enable = true;

  # ZFS
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  boot.zfs.extraPools = [ "storage" ];
  fileSystems."/storage" = {
    device = "storage";
    fsType = "zfs";
  };

  services.sanoid.datasets = {
    storage.useTemplate = [ "default" ];
  };

  # Docker
  virtualisation.docker.enable = true;
}
