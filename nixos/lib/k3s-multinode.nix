{
  ...
}:

{
  # For multi-node k3s clusters the nodes reach each other over the LAN
  networking.firewall.allowedTCPPorts = [
    6443 # kube-apiserver
    2379 # etcd client
    2380 # etcd peer
    10250 # kubelet metrics
  ];
  networking.firewall.allowedUDPPorts = [ 8472 ]; # flannel vxlan
}
