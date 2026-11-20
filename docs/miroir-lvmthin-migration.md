# miroir: loopfile → lvmthin migration (hail-mary)

Status: done 2026-11-19. All four hail-mary nodes run the `lvm` layout and the `thin` node
group. The `std` group stays for eridani and stepien (still loopfile).

## Why

Today every volume write goes ext4 → loopfile → btrfs (CoW, zstd) → NVMe. On grace, btrfs
metadata and CoW overhead plus etcd make up most of the ~200 GiB/day written. With `lvmthin`,
DRBD writes straight to a thin LV and no filesystem sits underneath.

## How miroir handles it

- The agent picks the backend from the node's pool (`MiroirNode.spec.pools[name=default]`).
  It does not use the `backend` recorded on each replica, which is informational.
- A reinstalled node is treated as wiped. Every leg is recreated as a full sync target from
  its peers ([miroir: Rebuilding a node is safe](https://github.com/home-operations/miroir)).
  This is the path xenonite took on 2026-11-19.
- Resync onto lvmthin stays thin: zero runs are sent as discards.
- The default pool's VG must be named `vg-miroir`. miroir names the pool LV `thinpool`.
  If the VG already exists (`lvmthin: {}`, no `device`), miroir only adds the thin pool to it.
  With `poolSize` unset, the pool takes all free extents.

So migrating a node means: switch its pool to lvmthin, then rebuild it. Data movement is
DRBD resync from the other nodes.

## Disk layout

The whole disk is one VG, `vg-miroir`. disko creates `root` and `etcd`. The miroir agent
creates `thinpool` from everything left (`poolSize` unset, so `--extents 100%FREE`).

```
disk
├─ BIOS boot      2M
├─ ESP            300M  vfat  /boot
└─ LVM PV         rest  → VG vg-miroir
   ├─ root        96G   btrfs, subvol @ only (checksums + zstd for the OS and images)
   ├─ etcd        8G    xfs   /var/lib/rancher/k3s/server/db
   └─ thinpool    rest  created by the miroir agent on first start
```

Resulting thin pool per node. These are approximate: LVM also reserves a 1G metadata LV and a
1G metadata spare.

| Node       | Disk | thinpool | Provisioned on node today |
| ---------- | ---- | -------- | ------------------------- |
| grace      | 238G | ~132G    | 44G                       |
| rocky      | 224G | ~118G    | 15G                       |
| astrophage | 238G | ~132G    | 120G                      |
| xenonite   | 477G | ~371G    | 267G                      |

### Consequences of a full-VG pool

- **Nothing can grow afterwards.** LVM can't shrink a thin pool, and the VG has no free
  extents, so root and etcd are fixed at 96G/8G. Moving that boundary means rebuilding the
  node.
- **Images must fit in 96G root.** kubelet image GC starts pruning at 85% disk use (~82G).
  Today grace and rocky hold 41G of images. xenonite held ~100G of game images before its
  rebuild, so expect GC to evict and re-pull game images there.
- **The thin pool is never overcommitted on these nodes:** each pool is larger than the
  volumes provisioned on it. A full thin pool would freeze every volume in it, so keep
  miroir's pool `data_percent` alert anyway.
- **etcd** moves off btrfs entirely. The `+C` rule in `lib/k3s.nix` stops mattering on
  migrated nodes.

## Repo changes (once)

1. `lib/disk.nix`: add an opt-in LVM layout. It's a disko `lvm_vg` named `vg-miroir` with a
   96G `root` btrfs LV and an 8G `etcd` xfs LV, leaving the rest of the VG unallocated. It
   also enables `services.lvm.boot.thin.enable` so the host can activate the thin pool at
   boot. eridani and stepien keep the current layout.
2. miroir topology (`kubernetes/apps/base/storage/miroir/config/topology.yaml`): add a second
   `MiroirNodeGroup` for label `storage.miroir.home-operations.com/class=thin`:

   ```yaml
   pools:
     - name: default
       lvmthin: {}   # VG pre-created by disko; pool takes all free extents
   ```

   Keep the name `default` so existing PVs and StorageClasses need no change.
3. Per host: switch the layout and change the node label (`class=std` → `class=thin`) in
   `lib/miroir.nix`, or make the label per host. k3s only applies `--node-label` at
   registration, so also run `kubectl label node <n> ...=thin --overwrite` during the cutover.
4. Don't add `+C` to loopfile dirs on a node with existing CoW files. btrfs refuses reflinks
   between CoW and nocow files, so miroir snapshots and clones fail. xenonite's
   `/var/lib/miroir/{volumes,snapshots}` were set `+C` by hand after its 2026-11-19 rebuild,
   when every file was new.

## Per-node cutover

Order used: rocky (least miroir data) → grace → xenonite → astrophage (NAS last, planned NFS outage). Do only one node at a
time, because etcd has 4 members and tolerates 1 down.

1. **Preflight:** all MiroirVolumes `Ready`, fresh volsync backups, and nothing else down.
   List single-replica non-cache volumes on the node and copy their loopfiles off. Caches
   don't need copying; they come back empty.
2. **Save identity:** `/var/lib/rancher` (minus `agent/containerd`), `/etc/rancher`,
   `/var/lib/tailscale`, `/etc/ssh/ssh_host_*`, `/etc/machine-id`, and
   `/etc/NetworkManager/system-connections`, all to another node. Don't copy
   `/var/lib/miroir-drbd.d`.
3. Cordon and drain, then `systemctl stop k3s && k3s-killall.sh`.
4. Reinstall with the new layout:
   `nixos-anywhere --flake .#<host> --phases kexec,disko,install`. Run it from grace, or with
   `--ssh-option ProxyJump=bwees@grace`, not over petrova.
5. Restore identity onto `/mnt`, plus any single-replica volumes. Those go onto a thin LV
   once the pool exists, or get restored from volsync. Then reboot.
6. Before the reinstalled node boots, clear its stale DRBD minors from every MiroirVolume
   status:

   ```bash
   for v in $(kubectl get miroirvolume -o json | jq -r --arg n <node> \
     '.items[] | select(.status.perNode[$n].drbdMinor) | .metadata.name'); do
     kubectl patch miroirvolume $v --subresource=status --type=json \
       -p "[{\"op\":\"remove\",\"path\":\"/status/perNode/<node>/drbdMinor\"}]"
   done
   ```

   This works around a miroir bug: the agent reuses the minor recorded in status without
   reserving it in `minor.assign`. On a wiped node, a fresh allocation can then take the same
   minor. drbdadm refuses the duplicate and every adjust on the node fails. grace hit this on
   2026-11-19: `pvc-af70cfa2` (diskless) and `pvc-e2de3832` both got 1013, and two diskful
   legs never came up. If it happens anyway: delete the colliding diskless leg's `.res`
   under `flock minor.lock`, then clear its status minor.
7. Label the node `class=thin`, and relabel its MiroirNode
   (`miroir.home-operations.com/node-group=thin`). A group never takes over a MiroirNode
   another group manages. Confirm the MiroirNode shows `lvmthin`. The agent creates
   `thinpool` in `vg-miroir` and every leg full-syncs.
8. Keep the node cordoned until `kubectl wait miroirvolumes --all
   --for=jsonpath='{.status.phase}'=Ready`, then uncordon. This avoids the
   diskless-stage mkfs bug.
9. Check snapshots work on the node: run a volsync job with a leg there.

## What the migration showed

- Stale `backend: loopfile` entries on replicas were harmless. Snapshots worked across mixed
  backends (an lvmthin leg on rocky, loopfile legs elsewhere).
- A `MiroirNodeGroup` won't take over a MiroirNode another group manages. Relabel the
  MiroirNode's `miroir.home-operations.com/node-group`, as in step 7.
- **Resync is fast on lvmthin.** xenonite's 31 legs (~26G of real data) synced in minutes.
  The loopfile resync earlier the same day wrote 170G, because loopfile legs skip discards.
- **Unreplicated volumes come back blank** (volsync caches and clones). miroir refuses to
  reformat them ("formatted before but … reads blank"). Delete the PVCs and volsync
  recreates them. Restore a real single-replica volume (`bwees-eglantine`) by `dd`-ing its
  saved image onto the new thin LV (`dd conv=sparse`) while the node is still cordoned.
- **Address disks by `/dev/disk/by-id` when other disks are present.** Inside the kexec
  installer, astrophage's boot SSD showed up as `sdb` and the ZFS cache disk as `sda`.
- **On the NAS:** stop the NFS consumers (suspend their HelmReleases, scale to 0, and
  pin `magpie-agent` off every node), then stop nfs/samba and `zpool export main` before the
  kexec. The pool imported on its own at boot (`boot.zfs.extraPools`, same `hostId`). Save
  `/etc/restic` and `/var/lib/samba` with the identity.
- disko's VM test fails shellcheck (SC2100) on `vg=vg-miroir`. That's a false positive:
  real installs don't lint the script (`disko.checkScripts = false`). Test with a hyphen-free
  VG name and small LVs (`rootSize = "2G"`) instead.
- During a grace cutover, point kubectl at another server (`--server https://rocky:6443`);
  the default kubeconfig targets grace.
