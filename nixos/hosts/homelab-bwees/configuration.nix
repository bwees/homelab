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
    ../../lib/docker.nix
    ../../lib/garbage_collect.nix
    ../../lib/root_ca.nix
    ../../lib/sanoid.nix
    ../../lib/tailscale.nix
    ../../lib/zfs_backup.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "homelab-bwees";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.ip = "100.65.90.4";
  services.tailscale.extraUpFlags = [ "--advertise-exit-node" ];

  # ZFS
  networking.hostId = "a183a60c"; # needed for zfs
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

  # nix-ld for vscode server
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    gcc14
    gnumake
  ];
}
