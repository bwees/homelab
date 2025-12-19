# NixOS

NixOS is used to manage all homelab nodes that support it. Each host has its own
directory under `nixos/hosts/` which contains the NixOS configuration for that host.

## Generate Hardware Configuration

```bash
nixos-generate-config --show-hardware-config --no-filesystems
```

## Default Disk Partitioning

Using Disko, the default partitioning scheme is as follows:

| Partition | Size      | Type                 | Mount Point |
| --------- | --------- | -------------------- | ----------- |
| boot      | 2 MiB     | BIOS boot partition  | N/A         |
| ESP       | 300 MiB   | EFI System Partition | /boot       |
| root      | Remainder | ext4 filesystem      | /           |

See `nixos/anywhere/disk-config.nix` for the Disko configuration that implements this
partitioning scheme.
