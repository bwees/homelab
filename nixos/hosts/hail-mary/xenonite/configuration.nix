{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../../lib/base-packages.nix
    ../../../lib/beszel.nix
    ../../../lib/bwees.nix
    ../../../lib/k3s.nix
    ../../../lib/k3s-multinode.nix
    ../../../lib/miroir.nix
    ../../../lib/miroir-drbd.nix
    ../../../lib/garbage-collect.nix
    ../../../lib/tailscale.nix
    ../../../lib/tailscale-pod-nat.nix
    ../../../lib/docker.nix
    ../../../lib/amd-gpu.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "xenonite";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.tailscale.extraUpFlags = [
    "--advertise-tags=tag:hail-mary,tag:nixos"
  ];

  # Fix GPU conflicts with the i915 driver
  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  services.k3s.serverAddr = "https://192.168.50.110:6443";
  services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";

  # create additional docker socket that can be folder mounted by wolf
  virtualisation.docker.daemon.settings.hosts = [
    "unix:///var/run/docker/docker.sock"
  ];

  systemd.services.docker.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/mkdir -p /var/run/docker"
  ];
}
