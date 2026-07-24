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
    ../../lib/tailscale.nix
    ../../lib/k3s.nix
    ../../lib/miroir.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "tau-ceti";
  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.tailscale.extraUpFlags = [
    "--advertise-tags=tag:tau-ceti,tag:nixos"
  ];

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
    "--accept-routes"
  ];

  services.k3s.extraFlags = [
    "--node-label=node.longhorn.io/create-default-disk=true"
    # Expose the public IP as the node's ExternalIP so the Tailscale operator can
    # advertise it as a static endpoint for direct ingress connections.
    # --node-ip must be pinned: otherwise k3s auto-detects a dual-stack node and
    # silently drops the IPv4-only --node-external-ip, leaving no ExternalIP.
    "--node-ip=45.137.192.163"
    "--node-external-ip=45.137.192.163"
  ];

  # Allow inbound UDP to the Tailscale ingress static-endpoint NodePorts on the
  # public interface. Must match spec.staticEndpoints.nodePort.ports of the
  # `tau-ceti-static-endpoints` ProxyClass.
  networking.firewall.allowedUDPPortRanges = [
    {
      from = 31670;
      to = 31690;
    }
  ];

  services.fail2ban.enable = true;
}
