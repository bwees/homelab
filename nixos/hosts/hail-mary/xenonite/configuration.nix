{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
    ../../../lib/base-packages.nix
    ../../../lib/beszel.nix
    ../../../lib/bwees.nix
    ../../../lib/k3s.nix
    ../../../lib/k3s-multinode.nix
    ../../../lib/miroir.nix
    ../../../lib/miroir-drbd.nix
    ../../../lib/garbage-collect.nix
    ../../../lib/netbird.nix
    ../../../lib/docker.nix
    ../../../lib/amd-gpu.nix
  ];

  system.stateVersion = "25.05";

  # Networking/Clock
  networking.hostName = "xenonite";
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  # IoT VLAN
  networking.networkmanager.ensureProfiles.profiles.iot0 = {
    connection = {
      id = "iot0";
      type = "vlan";
      interface-name = "iot0";
    };
    vlan = {
      parent = "enp7s0";
      id = "30";
    };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };

  networking.firewall.interfaces."iot0" = {
    allowedTCPPorts = [
      1883 # MQTT broker
    ];
    allowedUDPPorts = [
      5353 # mDNS service discovery
      5540 # Matter operational traffic
    ];
  };

  # hostNetwork pods bind on the node, so envoy arrives over the LAN (masqueraded
  # to its node's IP) instead of the pod CIDR that k3s already accepts.
  networking.firewall.interfaces."enp7s0".allowedTCPPorts = [
    8123 # Home Assistant
    5580 # Matter server websocket
  ];

  # Fix GPU conflicts with the i915 driver
  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  services.k3s.serverAddr = "https://192.168.50.110:6443";
  services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";

  # create additional docker socket that can be folder mounted by wolf
  virtualisation.docker.daemon.settings.hosts = [
    "unix:///var/run/docker/docker.sock"
  ];

  systemd.services.docker.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/mkdir -p /var/run/docker"
  ];
}
