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
    ../../lib/storage-backup.nix
    ../../lib/tailscale.nix
    ../../lib/k3s.nix
    ../../lib/miroir.nix
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

  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  # Expose the envoy ingress Service on the LAN, bound to the node IP 10.0.1.2.
  # Public DNS resolves *.home.bwees.dev here, so family devices reach it directly.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
