{ ... }:

{
  imports = [
    ./base-packages.nix
    ./beszel.nix
    ./bwees.nix
    ./disk.nix
    ./garbage-collect.nix
    ./network-tuning.nix
    ./tailscale.nix
  ];
}
