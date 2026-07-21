{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    wget
    btop
    git
    restic
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
