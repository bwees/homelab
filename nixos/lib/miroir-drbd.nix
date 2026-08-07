{ config, pkgs, ... }:

let
  drbd9 = config.boot.kernelPackages.drbd.overrideAttrs (prev: {
    version = "9.3.3";
    src = pkgs.fetchurl {
      url = "https://pkg.linbit.com/downloads/drbd/9/drbd-9.3.3.tar.gz";
      hash = "sha256-p7+wFgcMMd8cc4VpyozF5fwzfdRJFH979i50bYfTjyE=";
    };
    
    # upstream marks 9.3.2 broken on kernel 6.18; 9.3.3 is the release that fixes it
    meta = prev.meta // {
      broken = false;
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
