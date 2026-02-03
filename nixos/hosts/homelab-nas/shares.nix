{
  ...
}:

{
  services.samba = {
    enable = true;
    openFirewall = true;

    # Create Samba users corresponding to system users
    # Note: You must set a Samba password for each user
    # $ sudo smbpasswd -a yourusername

    settings = {
      global = {
        "server smb encrypt" = "required";
        "server min protocol" = "SMB3_00";
        "workgroup" = "WORKGROUP";
        "security" = "user";
      };

      personal = {
        "path" = "/mnt/main/personal/bwees";
        "writable" = "yes";
        "browseable" = "yes";
      };

      homelab = {
        "path" = "/mnt/main/homelab";
        "writable" = "yes";
        "browseable" = "yes";
      };
    };
  };

  # windows discovery
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # macOS discovery
  services.avahi = {
    enable = true;
    publish.enable = true;
    publish.userServices = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # NFS
  services.nfs.server = {
    enable = true;

    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;

    exports = ''
      /mnt/main/homelab   192.168.50.173(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,fsid=0)
    '';
  };

  # Open NFS ports
  networking.firewall.allowedUDPPorts = [
    111
    2049
    4000
    4001
    4002
  ];
  networking.firewall.allowedTCPPorts = [
    111
    2049
    4000
    4001
    4002
  ];
}
