{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";

  networking.hostName = "changeme";
  time.timeZone = "America/New_York";

  homelab.disk.device = "/dev/changeme";
}
