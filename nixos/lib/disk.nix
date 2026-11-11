{ config, lib, ... }:

let
  cfg = config.homelab.disk;
  btrfsMountOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  options.homelab.disk = {
    device = lib.mkOption {
      type = lib.types.str;
      example = "/dev/nvme0n1";
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

  config = {
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
            name = "root";
            size = "100%";
            content = {
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
          };
        };
      };
    };
  };
}
