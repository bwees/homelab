{
  pkgs-stable,
  ...
}:

{
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs-stable.docker;
  # dockerd is started with --containerd=/run/containerd/containerd.sock
  virtualisation.containerd.enable = true;
  virtualisation.docker.daemon.settings.hosts = [
    "unix:///var/run/docker.sock"
  ];

  # Trust Docker bridge interfaces to allow containers to reach Tailscale IPs
  networking.firewall.trustedInterfaces = [
    "docker0"
    "br-+"
  ];
}
