{
  config,
  lib,
  pkgs,
  ...
}:

{
  nix.settings.auto-optimise-store = true;

  nix.gc.automatic = true;
  nix.gc.dates = "daily";
  nix.gc.options = "--delete-older-than 7d";
}
