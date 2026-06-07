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
      "--kube-apiserver-arg=feature-gates=ImageVolume=true"
      "--kubelet-arg=feature-gates=ImageVolume=true"
    ];
  };

  services.rpcbind.enable = true;
  boot.supportedFilesystems = [ "nfs" ];

  networking.firewall.allowedTCPPorts = [ 6443 ];
  networking.firewall.allowedUDPPorts = [ 8472 ];

  users.groups.k3s = { };
  users.users.bwees.extraGroups = [ "k3s" ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  virtualisation.containerd.enable = true;

  environment.systemPackages = with pkgs; [
    fluxcd
    k9s
  ];
}