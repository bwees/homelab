{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Define option for Tailscale IP
  options.services.tailscale.ip = lib.mkOption {
    type = lib.types.str;
    description = "Tailscale IP address for this host";
  };

  config = {
    services.tailscale.enable = true;
    services.tailscale.useRoutingFeatures = "server";
  };
}
