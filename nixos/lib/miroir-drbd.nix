{ config, pkgs, ... }:

let
  drbd9 = config.boot.kernelPackages.drbd.overrideAttrs (_: {
    version = "9.3.3";
    src = pkgs.fetchurl {
      url = "https://pkg.linbit.com/downloads/drbd/9/drbd-9.3.3.tar.gz";
      hash = "sha256-p7+wFgcMMd8cc4VpyozF5fwzfdRJFH979i50bYfTjyE=";
    };
  });
in
{
  boot.extraModulePackages = [ drbd9 ];
  boot.kernelModules = [
    "drbd"
    "drbd_transport_tcp"
  ];
  boot.extraModprobeConfig = ''
    options drbd usermode_helper=disabled
  '';

  networking.firewall.allowedTCPPortRanges = [
    {
      from = 7000;
      to = 7999;
    }
  ];
}
