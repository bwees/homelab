{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../../lib/beszel-intel-gpu.nix
    ../../lib/k3s.nix
    ../../lib/miroir.nix
  ];

  system.stateVersion = "25.11";

  networking.hostName = "eridani";
  time.timeZone = "America/New_York";

  homelab.disk = {
    device = "/dev/sda";
    subvolumes."@miroir" = "/var/lib/miroir";
  };

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
    "--advertise-routes=10.0.1.0/24"
  ];

  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];
}
