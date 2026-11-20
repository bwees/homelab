{ config, lib, ... }:

let
  cfg = config.homelab.disk;
  btrfsMountOptions = [
    "compress=zstd"
    "noatime"
  ];
  # miroir derives its default pool's VG name from the pool; it is not configurable
  miroirVolumeGroup = "vg-miroir";
  etcdDataDir = "/var/lib/rancher/k3s/server/db";

  btrfsRoot = {
    type = "btrfs";
    extraArgs = [ "-f" ];
  }
  // (
    if cfg.flatRoot then
      {
        mountpoint = "/";
        mountOptions = btrfsMountOptions;
      }
    else
      {
        subvolumes = lib.mapAttrs (_: mountpoint: {
          inherit mountpoint;
          mountOptions = btrfsMountOptions;
        }) ({ "@" = "/"; } // cfg.subvolumes);
      }
  );

  isLvm = cfg.layout == "lvm";
in
{
  options.homelab.disk = {
    device = lib.mkOption {
      type = lib.types.str;
      example = "/dev/nvme0n1";
    };

    layout = lib.mkOption {
      type = lib.types.enum [
        "btrfs"
        "lvm"
      ];
      default = "btrfs";
      description = ''
        `btrfs`: one btrfs partition for the whole disk.
        `lvm`: one LVM VG shared by a btrfs root LV, an xfs etcd LV, and the miroir
        lvmthin pool, which the miroir agent creates from the remaining free space.
      '';
    };

    rootSize = lib.mkOption {
      type = lib.types.str;
      default = "96G";
      description = "Size of the root LV for the `lvm` layout.";
    };

    etcdSize = lib.mkOption {
      type = lib.types.str;
      default = "8G";
      description = "Size of the etcd LV for the `lvm` layout.";
    };

    subvolumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "@miroir" = "/var/lib/miroir";
      };
      description = "Btrfs subvolumes besides `@`, mapped to their mountpoints.";
    };

    flatRoot = lib.mkEnableOption "mounting the btrfs top level at / instead of an `@` subvolume";
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.flatRoot -> cfg.subvolumes == { };
          message = "homelab.disk.subvolumes needs a subvolume root; unset homelab.disk.flatRoot.";
        }
      ];

      boot.loader.grub = {
        efiSupport = true;
        efiInstallAsRemovable = true;
      };

      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = 4 * 1024;
        }
      ];

      disko.devices.disk.disk1 = {
        inherit (cfg) device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "2M";
              type = "EF02";
            };
            esp = {
              name = "ESP";
              size = "300M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              name = if isLvm then "lvm" else "root";
              size = "100%";
              content =
                if isLvm then
                  {
                    type = "lvm_pv";
                    vg = miroirVolumeGroup;
                  }
                else
                  btrfsRoot;
            };
          };
        };
      };
    }

    (lib.mkIf isLvm {
      disko.devices.lvm_vg.${miroirVolumeGroup} = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = cfg.rootSize;
            content = btrfsRoot;
          };
          etcd = {
            size = cfg.etcdSize;
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = etcdDataDir;
              mountOptions = [ "noatime" ];
            };
          };
        };
      };

      services.lvm.boot.thin.enable = true;

      systemd.tmpfiles.rules = [ "z ${etcdDataDir} 0700 root root -" ];
    })
  ];
}
