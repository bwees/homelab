{
  ...
}:

{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "main" ];

  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
}
