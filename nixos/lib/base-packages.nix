{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    wget
    btop
    python314
    git
    restic
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
