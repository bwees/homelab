{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Docker
  virtualisation.docker.enable = true;

  # Firewall configuration
  # Trust Docker bridge interfaces to allow containers to reach Tailscale IPs
  networking.firewall.trustedInterfaces = [
    "docker0"
    "br-+"
  ];
}
