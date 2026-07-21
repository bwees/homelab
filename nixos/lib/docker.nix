{
  pkgs-stable,
  ...
}:

{
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs-stable.docker;
  virtualisation.docker.daemon.settings.hosts = [
    "unix:///var/run/docker.sock"
  ];

  # Trust Docker bridge interfaces to allow containers to reach Tailscale IPs
  networking.firewall.trustedInterfaces = [
    "docker0"
    "br-+"
  ];
}
