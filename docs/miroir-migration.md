# Longhorn → miroir migration plan

Plan to replace [Longhorn](https://longhorn.io) with
[miroir](https://github.com/home-operations/miroir) as the replicated block-storage CSI
driver across every cluster in this repo.

## Why

miroir is a lightweight replicated-block CSI driver (LVM thin / ZFS / loopfile backends,
synchronous replication via DRBD9). It is positioned as "replicated block storage without
running Ceph" for small 2–3 node clusters — the same niche Longhorn fills here, with a much
smaller control-plane footprint (no manager/UI/instance-manager pods, no iSCSI dependency).

## Current state

Storage is defined once in the shared base and pulled into all four clusters.

| Piece | Where | Notes |
| --- | --- | --- |
| Longhorn CSI (`driver.longhorn.io`) | `kubernetes/apps/base/storage/longhorn/` | Helm chart `1.12.0`, ns `storage` |
| StorageClass `longhorn` | Longhorn default class | Default class, `reclaimPolicy: Retain`, replicas per-cluster |
| StorageClass `longhorn-volsync-src` | `longhorn/app/storageclass.yaml` | 1 replica, `Delete`, volsync PIT snapshots |
| VolumeSnapshotClass `longhorn` | `longhorn/app/volumesnapshotclass.yaml` | `driver.longhorn.io` |
| volsync (restic) | `kubernetes/apps/base/storage/volsync/` + `kubernetes/components/volsync/` | Nightly restic to B2 + NAS |
| snapshot-controller | `kubernetes/apps/base/storage/snapshot-controller/` | Shared, stays |

Per-cluster replica counts (`kubernetes/clusters/<cluster>/ks.yaml`):

| Cluster | Nodes | `LONGHORN_DATA_REPLICAS` |
| --- | --- | --- |
| eridani | single | `1` |
| tau-ceti | single | `1` |
| stepien | single | `1` |
| hail-mary | grace + rocky + xenonite (storage), astrophage (quorum-only) | `2` |

- **26 PVCs** currently use `storageClassName: longhorn`.
- Nodes are provisioned with NixOS (disko). Longhorn's data path is a dedicated btrfs
  subvolume `@longhorn` mounted at `/var/lib/longhorn` with `nodatacow`
  (`nixos/hosts/<host>/disk-config.nix`). There is **no spare disk/partition** and no ZFS
  pool — the root disk is a single btrfs volume.

## Key constraints

1. **No in-place conversion.** There is no Longhorn→miroir volume converter. Every PVC must
   be recreated on a miroir StorageClass and its data copied over. The existing volsync
   restic backups are the migration vehicle (backup on Longhorn → restore into a new miroir
   PVC). Any PVC not covered by volsync needs a manual copy job.
   - **miroir's PVC clone / snapshot-restore cannot bridge the two drivers.** CSI clone and
     snapshot-restore only work within a single provisioner — Kubernetes requires the source
     PVC and destination StorageClass to share the same provisioner, and miroir's clone works
     by cutting a hidden *miroir* snapshot. A `driver.longhorn.io` volume can't be a
     `dataSource` for a `miroir.home-operations.com` PVC. The clone/snapshot features are for
     copies *within* miroir (post-migration), not the Longhorn→miroir hop. The hop is always
     a data copy (volsync restic, or a one-shot `rsync` Job mounting both PVCs).
2. **Host-level prerequisites (NixOS).** All storage userland (`drbdadm`, `lvm`, `mkfs`,
   `mount.nfs`) ships inside the agent image; nodes only provide kernel modules and graceful
   shutdown. There are no NixOS setup docs upstream (only Talos + Debian/Ubuntu), so:
   - **loopfile (single-node clusters):** needs the `loop` module (present in the stock NixOS
     kernel, agent loads on demand) and a **reflink-capable filesystem** for the base dir.
     Our roots are **btrfs**, which is reflink-capable — so loopfile works out of the box,
     no NixOS change required beyond graceful shutdown.
   - **DRBD9 ≥ 9.3.1 (hail-mary only, for `replicas: 2`):** the in-tree `drbd.ko` is the 8.4
     API and does **not** work; a real DRBD9 out-of-tree module is required. **nixpkgs
     unstable ships only DRBD 9.2.16** (`config.boot.kernelPackages.drbd`), which is *below*
     miroir's 9.3.1 floor — the agent refuses to start on an older module. `lib/miroir-drbd.nix`
     therefore `overrideAttrs`-bumps the nixpkgs derivation to **9.3.3** (latest 9.3.x on
     LINBIT; real SRI hash baked in) and loads `drbd` + `drbd_transport_tcp` with
     `usermode_helper=disabled`. This override is the single biggest unknown — it must pass a
     real `nixos-rebuild build` on a hail-mary node (the 9.3.x source could need build tweaks
     the 9.2.x derivation doesn't cover). Validate before Phase 4.
   - **Graceful node shutdown** must be enabled so the agent (a `system-node-critical` pod)
     stops *after* workloads and can release DRBD backings before the pool exports. Note this
     repo's finding: `shutdownGracePeriod` is a kubelet **config-file** field, not a
     `--kubelet-arg` (passing it as a flag crash-loops k3s).
3. **Backend choice.** With a single btrfs root and no spare disk:
   - **loopfile** — sparse backing file on btrfs (reflink CoW). Zero repartition, simplest;
     chosen for the initial migration. Directly analogous to Longhorn's `/var/lib/longhorn`.
     Base dir `/var/lib/miroir` (must also be listed in the chart's `agent.loopfileBaseDirs`,
     which the scaffold already does).
   - **LVM thin** — needs a spare disk or dedicated partition
     (`/dev/disk/by-partlabel/r-miroir`); a destructive disko change / reprovision. Higher
     performance — revisit later if loopfile is too slow.
   - ZFS is not applicable (no pool).
4. **DRBD replication only matters on hail-mary** (`replicas: "2"`). The three single-node
   clusters use `replicas: "1"` (node-local) and don't need DRBD.
5. **Kubernetes ≥ 1.31** required — verify k3s version on every node before starting.

## Target state

| Piece | Replacement |
| --- | --- |
| Longhorn Helm release | miroir Helm release (`oci://ghcr.io/home-operations/charts/miroir`), ns `miroir-system` |
| `MiroirNode` per storage node | New — one per node (or a `MiroirNodeGroup` by node label) |
| StorageClass `longhorn` | StorageClass `miroir` (`provisioner: miroir.home-operations.com`), default class |
| StorageClass `longhorn-volsync-src` | StorageClass `miroir-volsync-src` (`replicas: "1"`, `Delete`) |
| VolumeSnapshotClass `longhorn` | VolumeSnapshotClass `miroir` (`driver: miroir.home-operations.com`) |
| volsync / snapshot-controller | Unchanged — only the class names they reference change |

## Migration steps

Do this **one cluster at a time**, single-node clusters first (eridani → tau-ceti → stepien),
then hail-mary. Longhorn and miroir can coexist during the transition — miroir is a separate
driver/namespace, so both CSIs run side by side until every PVC is moved.

### Phase 0 — Prep (no production impact)

1. Confirm k3s ≥ 1.31 on all nodes.
2. Host prerequisites in NixOS — **scaffolded** (`nixos/`):
   - **Graceful node shutdown** (`lib/k3s.nix`, all nodes): `shutdownGracePeriod: 120s` /
     `shutdownGracePeriodCriticalPods: 60s` added to the existing kubelet **config file**
     (not a `--kubelet-arg` — a flag crash-loops k3s), plus
     `services.logind.settings.Login.InhibitDelayMaxSec = 130` so logind holds the shutdown
     inhibitor past the grace period.
   - **Storage-backend modules** (`lib/miroir.nix`, imported by every k3s node):
     `boot.kernelModules = [ "loop" "dm_thin_pool" ]` (loopfile now, lvmthin later).
   - **Dedicated `@miroir` btrfs subvolume** mounted at `/var/lib/miroir` (the loopfile
     baseDir), added to each storage host's `disk-config.nix` — mirrors the existing
     `@longhorn` subvolume but **keeps CoW** (`noatime,compress=zstd`, *not* `nodatacow`):
     the loopfile backend needs reflink, which `nodatacow` disables. astrophage is excluded
     (root has no subvolume layout; its agent is client-only).
     - **disko only creates subvolumes at drive init**, so on the already-provisioned hosts
       the subvolume was created out-of-band (mount `subvolid=5`, `btrfs subvolume create
       @miroir`, unmount) on all six storage nodes: eridani, tau-ceti, stepien, grace, rocky,
       xenonite. It stays unmounted until the next `nixos-rebuild switch` picks up the disko
       mount entry.
     - **Ordering:** run `nixos-rebuild switch` on a node (mounts `@miroir`) *before* labeling
       it a miroir storage node. Otherwise the agent writes loop files into `/var/lib/miroir`
       on the root subvolume, and the later mount hides them.
   - **DRBD9** (`lib/miroir-drbd.nix`, imported by grace/rocky/xenonite only): overrides
     nixpkgs' 9.2.16 → 9.3.3 and loads `drbd` + `drbd_transport_tcp` with
     `usermode_helper=disabled`. **Not** on astrophage: its agent runs client-only (miroir
     allows nodes with no DRBD module), and it is never a replica or tie-breaker target
     because it is never labeled as a storage node.
   - Roll out per host with `nixos-rebuild` / `mise run nixos:*`. **Build-test the DRBD
     override on one hail-mary node first** (see risk above).
3. Take a fresh, verified volsync backup of every app so a known-good restore point exists
   before touching anything.

### Phase 1 — Install miroir alongside Longhorn — **scaffolded**

The manifests for this phase are committed under
`kubernetes/apps/base/storage/miroir/`, split into a driver Kustomization and a
cluster-scoped config Kustomization (config `dependsOn` the driver, so the miroir CRDs exist
before the topology/StorageClass/VolumeSnapshotClass apply — and the cluster-scoped
`MiroirNodeGroup` is never namespace-stamped):

```
miroir/
  ks.yaml                      # Flux Kustomizations: miroir (driver) + miroir-config
  app/                         # namespaced driver → targetNamespace miroir-system
    namespace.yaml             #   ns miroir-system, PSA enforce=privileged
    ocirepository.yaml         #   oci://ghcr.io/home-operations/charts/miroir  tag 0.11.4
    helmrelease.yaml           #   agent.loopfileBaseDirs=[/var/lib/miroir], gateway.enabled=false
    kustomization.yaml
  config/                      # cluster-scoped, no namespace
    topology.yaml              #   MiroirNodeGroup "std" (loopfile /var/lib/miroir, label-selected)
    storageclass.yaml          #   miroir (Retain, replicas ${MIROIR_DATA_REPLICAS}) + miroir-volsync-src (1, Delete)
    volumesnapshotclass.yaml   #   miroir
    kustomization.yaml
```

Also wired: `miroir/ks.yaml` added to `kubernetes/apps/base/storage/kustomization.yaml`, and
`MIROIR_DATA_REPLICAS` added to every `kubernetes/clusters/<cluster>/ks.yaml` postBuild
(`1` for eridani/tau-ceti/stepien, `2` for hail-mary). Longhorn stays the default
StorageClass — the `miroir` class deliberately has **no** `is-default-class` annotation yet.

The topology uses a **`MiroirNodeGroup`** (label selector
`storage.miroir.home-operations.com/class: std`) rather than per-node `MiroirNode` resources,
so the base stays cluster-agnostic — a node becomes a miroir storage node simply by being
labeled.

**Activation steps (after the NixOS prereqs land):**

1. Commit + push; confirm the `miroir` and `miroir-config` Kustomizations reconcile and the
   `miroir-system` controller + agent DaemonSet are healthy. Until nodes are labeled, agents
   run **client-only** and no pools are provisioned — harmless.
2. Label the storage nodes to materialize their `MiroirNode` and provision loopfile pools:
   ```bash
   kubectl label node <node> storage.miroir.home-operations.com/class=std
   ```
   (single-node clusters: their one node; hail-mary: grace, rocky, xenonite — **not**
   astrophage, which stays quorum-only/storage-free).
3. Verify: `kubectl get miroirnodes` shows the labeled nodes Ready, and a scratch PVC on the
   `miroir` class binds and mounts.

### Phase 2 — Migrate PVCs (per app)

For each app, using volsync as the copy mechanism (this is the standard volsync
backup-then-restore-into-new-storageclass flow):

1. Scale the app down (`replicas: 0` / suspend its Flux Kustomization) to quiesce writes.
2. Ensure the latest restic snapshot is current.
3. Point the app's PVC at the `miroir` StorageClass and let volsync restore the restic
   snapshot into the freshly provisioned miroir PVC (`ReplicationDestination`, or the
   bootstrap-restore pattern this repo already uses via `kubernetes/components/volsync/`).
4. Scale the app back up; verify data and health.
5. Once confirmed, delete the old Longhorn PVC/PV (they are `Retain`, so they linger as
   released volumes — clean them up deliberately; see the known orphan-PV behavior with
   Retain + volsync in this repo's history).

Migrate a low-risk app first (e.g. gatus/beszel) to validate the flow end-to-end before
touching stateful heavies like immich and gitea.

### Phase 3 — Flip defaults and retire Longhorn (per cluster)

1. When every PVC in a cluster is on miroir, make `miroir` the default StorageClass and
   unset Longhorn's default.
2. Update volsync class defaults so new backups use miroir:
   - `VOLSYNC_SNAPSHOTCLASS` → `miroir`
   - `VOLSYNC_PIT_STORAGECLASS` → `miroir-volsync-src`
   - `VOLSYNC_STORAGECLASS` → `miroir`
   These are defaulted inline in `kubernetes/components/volsync/replicationsource.yaml`;
   update the `:=` fallbacks and any per-app overrides.
3. Confirm no PV/PVC references `driver.longhorn.io` anywhere.
4. Remove the Longhorn app from base storage (`kustomization.yaml` + delete
   `longhorn/`), let Flux prune it.
5. Reclaim host resources in NixOS: drop the `@longhorn` subvolume + `/var/lib/longhorn`
   mount from each `disk-config.nix`, and remove the `iscsi_tcp` module + openiscsi service
   from `lib/k3s.nix` (Longhorn-only). Just as disko doesn't *create* subvolumes on a switch,
   it doesn't *delete* them: after `nixos-rebuild switch` drops the mount, remove the data
   out-of-band (`mount subvolid=5`, `btrfs subvolume delete @longhorn`) on each node — only
   once every PVC is confirmed migrated and backed up.

### Phase 4 — hail-mary (replicated)

Same as Phases 1–3 but with `replicas: "2"` and DRBD in play:

- Validate DRBD replication with a test PVC (write on one node, kill it, confirm the replica
  serves the data) **before** migrating real workloads.
- Keep the `dedicated=storage` taint/toleration story intact: miroir's node/agent pods must
  tolerate the taint on astrophage the same way the Longhorn manager/driver do today, and
  astrophage stays storage-free (quorum-only).

## Risks / open questions

- **DRBD on NixOS** is the biggest unknown — nixpkgs ships 9.2.16, so `lib/miroir-drbd.nix`
  overrides it to 9.3.3. That override must actually **build** (`nixos-rebuild build`) and the
  loaded module must report ≥ 9.3.1 (`modinfo drbd`) on a hail-mary node before Phase 4.
- **loopfile performance** vs Longhorn on btrfs — acceptable for most apps here, but
  benchmark immich/gitea; consider LVM thin (reprovision) if it's too slow.
- **No spare disk** means LVM thin needs a destructive disko change; deferred by choosing
  loopfile first.
- **RWX volumes** — miroir does RWX via per-volume NFS exports. Audit whether any current
  PVC uses `ReadWriteMany` (media library / share apps) before assuming a clean swap.
- **k3s < 1.31** on any node blocks the whole thing — check first.

## Rollback

Because both drivers coexist until Phase 3, rollback per app is: scale down, repoint the PVC
back at the `longhorn` class, volsync-restore, scale up. Nothing is destructive until the
deliberate Longhorn PV cleanup and the base-storage removal in Phase 3.
