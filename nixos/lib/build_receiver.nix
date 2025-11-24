{
  config,
  lib,
  pkgs,
  ...
}:

{
  # this is generated in "build_sender.nix"
  users.users.bwees.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjOHUEbSyeqplwj9nlCLWDTH1tqzFSUrsz9cstTb5Xd"
  ];
}
