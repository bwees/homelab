{
  pkgs,
  ...
}:

{
  imports = [
    ./restic-copies.nix
  ];

  services.restic = {
    backups = {
      local = {
        initialize = true;
        environmentFile = "/etc/restic/credentials/restic.local.env";
        paths = [ "/storage" ];

        exclude = [
          # ignore the snapshot directory
          "/storage/@snapshot"
        ];

        pruneOpts = [
          "--keep-within 7d"
          "--keep-weekly 2"
          "--keep-monthly 2"
          "--keep-yearly 1"
        ];

        timerConfig = {
          OnCalendar = [
            "00:00"
            "12:00"
          ];
          Persistent = true;
        };

        backupPrepareCommand = ''
          set -Eeuxo pipefail

          # clean old snapshot
          if btrfs subvolume delete /storage/@snapshot; then
              echo "WARNING: previous run did not cleanly finish, removing old snapshot"
          fi

          btrfs subvolume snapshot -r /storage /storage/@snapshot

          # unmounting here does not affect the host mount
          umount /storage
          mount -t btrfs -o subvol=@storage/@snapshot /dev/disk/by-partlabel/disk-disk1-root /storage
        '';

        backupCleanupCommand = ''
          btrfs subvolume delete /storage/@snapshot
        '';

        copies = {
          nas.environmentFile = "/etc/restic/credentials/restic.nas.env";
          b2.environmentFile = "/etc/restic/credentials/restic.b2.env";
        };
      };
    };
  };

  systemd.services.restic-backups-local = {
    path = with pkgs; [
      btrfs-progs
      umount
      mount
    ];

    serviceConfig = {
      # need PrivateMounts to not interfere with host mounts
      PrivateMounts = true;
    };
  };
}
