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

  networking.hostName = "stepien";
  time.timeZone = "America/New_York";

  homelab.disk = {
    device = "/dev/nvme0n1";
    subvolumes."@miroir" = "/var/lib/miroir";
  };

  # Prefer IPv4 over IPv6 due to IPv6 issues with ISP
  networking.enableIPv6 = false;

  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
  ];
}
