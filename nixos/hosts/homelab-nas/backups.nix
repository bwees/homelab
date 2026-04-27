{
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../lib/storage-backup.nix
  ];

  # Sanoid for ZFS snapshot management
  services.sanoid = {
    enable = true;
    datasets = {
      "main/personal" = {
        autosnap = true;
        autoprune = true;

        daily = 7;
        monthly = 4;
      };
    };
  };

  services.restic.backups.local.copies = lib.mkForce {
    b2.environmentFile = "/etc/restic/credentials/restic.b2.env";
  };

  # Main ZFS Pool Backup
  services.restic.backups.main = {
    initialize = true;
    environmentFile = "/etc/restic/credentials/restic.b2.env";

    paths = [ "/mnt/main" ];

    exclude = [
      "/mnt/main/media/movies"
      "/mnt/main/media/tv"
      "/mnt/main/restic"
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

      # clean up any leftover snapshot from a prior failed run
      zfs destroy -r main@restic-backup 2>/dev/null || true

      zfs snapshot -r main@restic-backup

      # only affects this service's mount namespace
      umount -R /mnt/main

      mount -t zfs main@restic-backup               /mnt/main
      mount -t zfs main/homelab@restic-backup       /mnt/main/homelab
      mount -t zfs main/personal@restic-backup      /mnt/main/personal
      mount -t zfs main/personal/bwees@restic-backup /mnt/main/personal/bwees
      mount -t zfs main/restic@restic-backup        /mnt/main/restic
    '';

    backupCleanupCommand = ''
      umount -R /mnt/main || true
      zfs destroy -r main@restic-backup
    '';
  };

  systemd.services.restic-backups-main = {
    path = with pkgs; [
      zfs
      umount
      mount
    ];

    serviceConfig = {
      PrivateMounts = true;
    };
  };
}
