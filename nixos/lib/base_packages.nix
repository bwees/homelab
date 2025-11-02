{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    wget
    htop
    python314
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
