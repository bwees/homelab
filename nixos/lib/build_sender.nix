{
  config,
  lib,
  pkgs,
  ...
}:

{

  # used for logging in to transfer builds
  services.openssh.hostKeys = [
    {
      path = "/root/.ssh/build_ed25519_key";
      type = "ed25519";
    }
  ];

  programs.ssh.extraConfig = ''
    Host homelab-linode
      IdentityFile /root/.ssh/build_ed25519_key
  '';
}
