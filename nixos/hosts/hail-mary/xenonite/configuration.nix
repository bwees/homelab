{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../../lib/docker.nix
    ../../../lib/iot-vlan.nix
    ../../../lib/amd-gpu.nix
  ];

  system.stateVersion = "25.05";

  networking.hostName = "xenonite";

  homelab.disk = {
    device = "/dev/nvme0n1";
    subvolumes."@miroir" = "/var/lib/miroir";
  };

  homelab.iotVlan.parent = "enp6s0";

  # Keep simpledrm from holding the display before amdgpu loads
  boot.kernelParams = [ "initcall_blacklist=simpledrm_platform_driver_init" ];

  # create additional docker socket that can be folder mounted by wolf
  virtualisation.docker.daemon.settings.hosts = [
    "unix:///var/run/docker/docker.sock"
  ];

  systemd.services.docker.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/mkdir -p /var/run/docker"
  ];
}
