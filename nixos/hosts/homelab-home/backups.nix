{
  config,
  lib,
  pkgs,
  ...
}:

{
  services.restic.backups = {
    local = {
      initialize = true;
      environmentFile = "/etc/restic/credentials/restic.local.env";
      paths = [ "/storage" ];

      exclude = [
        # ignore the snapshot directory
        "/storage/@snapshot"
      ];

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 2"
        "--keep-monthly 2"
        "--keep-yearly 1"
      ];

      timerConfig = {
        OnCalendar = "*-*-* 00,12:00:00"; # Twice daily at midnight and noon
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

    unitConfig = {
      # Copy to remote after local backup completes
      OnSuccess = "restic-backups-remote.service";
    };
  };

  # Service to copy local restic snapshots to NAS and B2
  systemd.services.restic-backups-remote = {
    description = "Restic local repository clone to remote repositories";

    path = with pkgs; [ restic ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };

    script = ''
      set -Eeuao pipefail

      source /etc/restic/credentials/restic.from-local.env

      # Copy to NAS
      echo "Copying snapshots from local to NAS..."
      source /etc/restic/credentials/restic.nas.env
      restic copy

      echo "Cleaning up old snapshots on NAS..."
      restic forget --prune --keep-daily 7 --keep-weekly 2 --keep-monthly 2 --keep-yearly 1


      echo "Copying snapshots from local to B2..."
      source /etc/restic/credentials/restic.b2.env
      restic copy
      echo "Cleaning up old snapshots on B2..."
      restic forget --prune --keep-daily 7 --keep-weekly 2 --keep-monthly 2 --keep-yearly 1

      echo "Snapshot copy completed successfully"
    '';
  };
}
