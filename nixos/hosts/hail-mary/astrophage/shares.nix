{
  config,
  ...
}:

let
  homelabRoot = "/mnt/main/homelab";
  personalRoot = "/mnt/main/personal/bwees";

  # Every pod on hail-mary runs as 1000:1000, so the NAS owns homelab data as that id.
  homelabId = 1000;
  homelabUser = config.users.users.homelab.name;
  homelabGroup = config.users.groups.homelab.name;

  homelabFolders = [
    "dropla"
    "games"
    "gitea"
    "media"
    "photos"
  ];

  nfsOptions = "rw,sync,no_subtree_check,fsid=0,all_squash,anonuid=${toString homelabId},anongid=${toString homelabId}";
in
{
  users.groups.homelab.gid = homelabId;
  users.users.homelab = {
    uid = homelabId;
    group = "homelab";
    isSystemUser = true;
  };
  users.users.bwees.extraGroups = [ "homelab" ];

  systemd.tmpfiles.rules = map (dir: "d ${dir} 2775 ${homelabUser} ${homelabGroup} -") (
    [ homelabRoot ] ++ map (folder: "${homelabRoot}/${folder}") homelabFolders
  );

  services.samba = {
    enable = true;
    openFirewall = true;

    # Create Samba users corresponding to system users
    # Note: You must set a Samba password for each user
    # $ sudo smbpasswd -a yourusername

    settings = {
      global = {
        "server min protocol" = "SMB3_00";
        "vfs objects" = "catia fruit streams_xattr";
        "fruit:metadata" = "stream";
        "fruit:model" = "MacSamba";
        "fruit:posix_rename" = "yes";
        "fruit:veto_appledouble" = "no";
        "fruit:nfs_aces" = "no";
        "fruit:wipe_intentionally_left_blank_rfork" = "yes";
        "fruit:delete_empty_adfiles" = "yes";
        "spotlight" = "no";
        "workgroup" = "WORKGROUP";
        "security" = "user";
      };

      personal = {
        "path" = personalRoot;
        "writable" = "yes";
        "browseable" = "yes";
        "valid users" = "bwees";
      };

      homelab = {
        "path" = homelabRoot;
        "writable" = "yes";
        "browseable" = "yes";
        "valid users" = "bwees";
        "force user" = homelabUser;
        "force group" = homelabGroup;
        "create mask" = "0664";
        "directory mask" = "2775";
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
      ${homelabRoot}   192.168.50.0/24(${nfsOptions})
      ${homelabRoot}   100.64.0.0/10(${nfsOptions},insecure)
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
