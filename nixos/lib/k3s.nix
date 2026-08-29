{ pkgs, config, ... }:

let
  # imageMaximumGCAge is a KubeletConfiguration-only field (no equivalent
  # --kubelet-arg flag), so it must be supplied via a config file.
  kubeletConfig = pkgs.writeText "k3s-kubelet-config.yaml" ''
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    imageMaximumGCAge: "168h"
    shutdownGracePeriod: "120s"
    shutdownGracePeriodCriticalPods: "60s"
  '';
in
{
  # The injected NetBird clients (ingress, dns, wolf, media egress) run as pods, and
  # flannel's masquerade would otherwise leave every one of them relay-only.
  imports = [ ./netbird-pod-nat.nix ];

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
      "--kubelet-arg=config=${kubeletConfig}"
      "--etcd-snapshot-schedule-cron=0 */6 * * *"
      "--etcd-snapshot-retention=14"
    ];
  };

  services.rpcbind.enable = true;
  boot.supportedFilesystems = [ "nfs" ];

  services.logind.settings.Login.InhibitDelayMaxSec = 130;

  # expose k3s ports to the NetBird interface for remote access
  # use k3s-multinode.nix for multi-node clusters, which exposes the same ports on the LAN interface
  networking.firewall.interfaces."wt0".allowedTCPPorts = [
    6443 # kube-apiserver
    10250 # kubelet metrics
  ];

  users.groups.k3s = { };
  users.users.bwees.extraGroups = [ "k3s" ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
  virtualisation.containerd.enable = true;

  environment.systemPackages = with pkgs; [
    fluxcd
    k9s
    nfs-utils
  ];
}
