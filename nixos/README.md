# NixOS

NixOS is used to manage all homelab nodes that support it. Each host has its own
directory under `nixos/hosts/` which contains the NixOS configuration for that host.
Settings shared by every host live in `lib/common.nix`, and the hail-mary nodes share
`hosts/hail-mary/common.nix`.

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
| root      | Remainder | btrfs filesystem     | see below   |

The root partition holds an `@` subvolume mounted at `/`, plus any extra subvolumes a
host lists in `homelab.disk.subvolumes`. All btrfs mounts use `compress=zstd,noatime`.
A 4 GiB swapfile lives at `/var/lib/swapfile`.

See `lib/disk.nix` for the Disko configuration that implements this partitioning scheme.
