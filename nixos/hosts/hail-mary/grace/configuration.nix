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
    ../../../lib/tailscale.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "grace";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.tailscale.extraUpFlags = [ 
    "--advertise-exit-node"
    "--advertise-tags=tag:hail-mary,tag:nixos"
  ];

  services.beszel.agent.enable = true;
  services.beszel.agent.environment = {
    "KEY" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKL+/R5W0b6x/4/bbbcNr/k2yQ96MIbXesRDWxgXWQtD";
  };

  # i915 replaces the early simpledrm framebuffer (card0) at boot, leaving a
  # dangling /dev/dri/by-path/...-simple-framebuffer.0-card symlink that the
  # Intel GPU device plugin advertises, breaking GPU container creation.
  # Blacklisting simpledrm stops card0 (and the stale symlink) being created.
  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  services.k3s.clusterInit = true;
  services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";

  # Longhorn: only nodes with this label get a default disk
  # (createDefaultDiskLabeledNodes=true in the longhorn HelmRelease).
  services.k3s.extraFlags = [
    "--node-label=node.longhorn.io/create-default-disk=true"
  ];
}
