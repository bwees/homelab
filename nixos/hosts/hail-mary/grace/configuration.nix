{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../../lib/beszel-intel-gpu.nix
    ../../../lib/iot-vlan.nix
  ];

  system.stateVersion = "25.05";

  networking.hostName = "grace";

  homelab.disk = {
    device = "/dev/nvme0n1";
    layout = "lvm";
  };

  homelab.iotVlan.parent = "enp1s0";

  # Fix GPU conflicts with the i915 driver
  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  services.k3s.clusterInit = true;
}
