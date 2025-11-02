{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings.hosts = [
    "unix:///var/run/docker.sock"
    "tcp://${config.services.tailscale.ip}:2375"
  ];

  # Firewall configuration
  # Trust Docker bridge interfaces to allow containers to reach Tailscale IPs
  networking.firewall.trustedInterfaces = [
    "docker0"
    "br-+"
  ];

  # Allow Docker API access on Tailscale IP
  networking.firewall.allowedTCPPorts = [ 2375 ];
}
