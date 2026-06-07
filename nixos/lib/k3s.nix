{ config, pkgs, ... }:

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
      "--kube-apiserver-arg=feature-gates=ImageVolume=true@server:*"
      "--kubelet-arg=feature-gates=ImageVolume=true@server:*"
    ];
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 6443 ];

  users.groups.k3s = { };
  users.users.bwees.extraGroups = [ "k3s" ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  virtualisation.containerd.enable = true;

  environment.systemPackages = with pkgs; [
    fluxcd
  ];
}