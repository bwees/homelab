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
    ../../lib/netbird.nix
    ../../lib/k3s.nix
    ../../lib/miroir.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "tau-ceti";
  time.timeZone = "America/New_York";

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  services.k3s.extraFlags = [
    # Pins the node's addresses to the public IPv4. --node-ip has to be explicit:
    # otherwise k3s auto-detects a dual-stack node and silently drops the
    # IPv4-only --node-external-ip, leaving no ExternalIP at all.
    "--node-ip=45.137.192.163"
    "--node-external-ip=45.137.192.163"
  ];

  # envoy-dfp claims the public IP as a Service externalIP and forward-proxies
  # *.bwees.io to whichever cluster owns the hostname.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.fail2ban.enable = true;
}
