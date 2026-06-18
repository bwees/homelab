{
  config,
  lib,
  ...
}:

{
  users.users.bwees = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];

    openssh.authorizedKeys.keys = [
     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJr7fOsF74yPo/dhdorxFhgnCURWPVDkIjeRz2md0Jzq" # bwees SSH Key
     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDn42VXrrAvqNscrPuZxKR1zRUldp8ZZKRVT7yFwPW97" # GH Actions Deployment SSH Key
    ];
  };

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;

  users.users.root.openssh.authorizedKeys.keys = lib.concatLists [
    config.users.users.bwees.openssh.authorizedKeys.keys
  ];

  security.sudo.extraRules = [
    {
      users = [ "bwees" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
