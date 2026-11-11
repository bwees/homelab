{ config, lib, ... }:

let
  # grace runs clusterInit; the other nodes join through it
  initServerAddr = "https://192.168.50.110:6443";
in
{
  imports = [
    ../../lib/k3s.nix
    ../../lib/k3s-multinode.nix
    ../../lib/miroir.nix
    ../../lib/miroir-drbd.nix
    ../../lib/tailscale-pod-nat.nix
  ];

  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";
  services.k3s.serverAddr = lib.mkIf (!config.services.k3s.clusterInit) initServerAddr;
}
