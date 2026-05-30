{ config, lib, pkgs, ... }:

{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"          # we manage Traefik via Flux/Helm to control version + Gateway API
      "--disable=local-storage"    # replaced by csi-driver-nfs + local-path-provisioner (managed)
      "--write-kubeconfig-mode=0640"
      "--write-kubeconfig-group=k3s"   # let members of the k3s group read the kubeconfig
      "--tls-san=${config.services.tailscale.ip}"
      "--node-ip=${config.services.tailscale.ip}"     # cluster traffic stays on Tailscale
      "--flannel-iface=tailscale0"
    ];
  };

  # k3s needs these open on the Tailscale interface for kubectl/flux access
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 6443 ];

  # Group that owns the kubeconfig (see --write-kubeconfig-group above) so
  # bwees can run kubectl/flux without sudo.
  users.groups.k3s = { };
  users.users.bwees.extraGroups = [ "k3s" ];

  # Point client tools at k3s's kubeconfig instead of the legacy localhost:8080.
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Keep containerd's GC sane (mirrors the spirit of garbage-collect.nix)
  virtualisation.containerd.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    fluxcd
  ];
}