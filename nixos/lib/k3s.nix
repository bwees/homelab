{ pkgs, config, ... }:

{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = [
      "--disable=traefik"
      "--disable=local-storage"
      "--disable=metrics-server"
      "--write-kubeconfig-mode=0640"
      "--write-kubeconfig-group=k3s"
      "--kube-apiserver-arg=feature-gates=ImageVolume=true"
      "--kubelet-arg=feature-gates=ImageVolume=true"
      "--etcd-snapshot-schedule-cron=0 */6 * * *"
      "--etcd-snapshot-retention=14"
    ];
  };

  services.rpcbind.enable = true;
  boot.supportedFilesystems = [ "nfs" ];

  services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";

  networking.firewall.allowedTCPPorts = [
    6443       # kube-apiserver
    2379       # etcd client
    2380       # etcd peer
    10250      # kubelet metrics
  ];
  networking.firewall.allowedUDPPorts = [ 8472 ]; # flannel vxlan

  users.groups.k3s = { };
  users.users.bwees.extraGroups = [ "k3s" ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  virtualisation.containerd.enable = true;

  environment.systemPackages = with pkgs; [
    fluxcd
    k9s
    nfs-utils
  ];

  ### Longhorn
  services.openiscsi = {
    enable = true;
    name = "iqn.2025-06.lab.bwees:${config.networking.hostName}";
  };

  boot.kernelModules = [ "iscsi_tcp" ]; 
}