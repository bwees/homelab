{
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
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "grace";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.tailscale.extraUpFlags = [
    "--advertise-tags=tag:hail-mary,tag:nixos"
  ];

  # Fix GPU conflicts with the i915 driver
  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  services.k3s.clusterInit = true;
  services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";
  services.k3s.extraFlags = [
    "--node-label=node.longhorn.io/create-default-disk=true"
  ];
}
