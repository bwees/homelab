{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../../lib/iot-vlan.nix
    ../../../lib/amd-gpu.nix
  ];

  system.stateVersion = "25.05";

  networking.hostName = "xenonite";

  homelab.disk = {
    device = "/dev/nvme0n1";
    layout = "lvm";
  };

  homelab.iotVlan.parent = "enp6s0";

  # Keep simpledrm from holding the display before amdgpu loads
  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];
}
