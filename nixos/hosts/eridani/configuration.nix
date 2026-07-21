{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../lib/base-packages.nix
    ../../lib/beszel.nix
    ../../lib/bwees.nix
    ../../lib/garbage-collect.nix
    ../../lib/root-ca.nix
    ../../lib/storage-backup.nix
    ../../lib/tailscale.nix
    ../../lib/k3s.nix
  ];

  system.stateVersion = "25.11";

  networking.hostName = "eridani";
  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
    "--advertise-routes=10.0.1.0/24"
  ];

  services.k3s.extraFlags = [
    "--node-label=node.longhorn.io/create-default-disk=true"
  ];

  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  # Expose the klipper LoadBalancer services on the LAN: PowerDNS (:53) serves
  # *.wees.home to the home network, and envoy-internal (:80/:443) serves the
  # cluster's internal HTTP(S) ingress. All bind the node IP 10.0.1.2.
  networking.firewall.allowedTCPPorts = [
    53
    80
    443
  ];
  networking.firewall.allowedUDPPorts = [ 53 ];
}
