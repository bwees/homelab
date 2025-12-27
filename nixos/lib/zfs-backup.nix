{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.sanoid = {
    enable = true;
    interval = "hourly";

    templates = {
      default = {
        autosnap = true;
        autoprune = true;
        hourly = 4;
        daily = 7;
        monthly = 2;
        yearly = 0;
      };
    };
  };
}
