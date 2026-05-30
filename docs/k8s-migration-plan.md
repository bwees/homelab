# Homelab → Kubernetes Migration Plan

> Status: **planning / evaluation** — no infrastructure changes have been made.
> This document is the agreed design for migrating the homelab from Docker Compose +
> Ansible to one Kubernetes cluster per node, managed with Flux.

## Table of contents

1. [Goals](#1-goals)
2. [Decisions (locked)](#2-decisions-locked)
3. [Target architecture](#3-target-architecture)
4. [Cluster layer: k3s on NixOS](#4-cluster-layer-k3s-on-nixos)
5. [GitOps layer: Flux monorepo](#5-gitops-layer-flux-monorepo)
6. [Ingress: Traefik on Gateway API](#6-ingress-traefik-on-gateway-api)
7. [Routing — co-located declaration, commit-time generation](#7-routing--co-located-declaration-commit-time-generation)
8. [TLS & DNS](#8-tls--dns)
9. [Secrets: SOPS + age (all-in)](#9-secrets-sops--age-all-in)
10. [Storage: csi-driver-nfs](#10-storage-csi-driver-nfs)
11. [Media stack: SOCKS5 egress + NetworkPolicy kill-switch](#11-media-stack-socks5-egress--networkpolicy-kill-switch)
12. [Cross-cutting: monitoring, backups, images, renovate](#12-cross-cutting-monitoring-backups-images-renovate)
13. [Per-service migration map](#13-per-service-migration-map)
14. [Phased rollout](#14-phased-rollout)
15. [Risks & things to validate](#15-risks--things-to-validate)

---

## 1. Goals

- **One Kubernetes cluster per node** (lab, home, vps, nas, stepien), each independent.
- **Flux** for GitOps across all clusters from a single monorepo.
- **Define a public service once** — its public hostname should live in exactly one
  place and propagate everywhere (DNS, VPS routing, TLS) automatically.
- **Media egress redesign** — replace the privileged kernel-mode Tailscale `exitnode`
  (shared netns) with an unauthenticated **SOCKS5 proxy** that apps opt into via a
  **label**, enforced by NetworkPolicy (the "join a network" model).
- **Better secrets** — manage all secrets as SOPS-encrypted, git-native files; no external
  secret service, decrypted only in-cluster by Flux.
- **Mount the NAS over NFS** into pods.

---

## 2. Decisions (locked)

| Area | Decision | Rationale |
|---|---|---|
| Distro | **k3s**, single-node cluster per host | First-class NixOS module; tiny (fits the 1 GB Linode); bundles a NetworkPolicy controller (kube-router) so the media egress kill-switch works with no CNI swap |
| GitOps | **Flux**, monorepo, per-cluster path | Decentralized — each cluster reconciles itself, no single control-plane SPOF across the WAN; native SOPS decryption |
| Ingress | **Traefik on Gateway API** (HTTPRoute) | Keep the Traefik data plane we know; modernize the config surface to Gateway API without adopting an Envoy stack |
| Public routing | **Co-located per-app HTTPRoute (+ `public-host` annotation) → pre-commit generator emits the VPS public routes + bind9 zones into the repo; Flux applies** | Routing lives next to the workload; cross-cluster artifacts are generated at commit time — no runtime component, no cross-cluster creds, bind9 stays static |
| Secrets | **SOPS + age (all-in)** — every secret is an encrypted file in git, decrypted by Flux at apply time | Fully git-native, no runtime secret service or external vault; editable via the VS Code SOPS extension; per-cluster keys for isolation |
| Storage | **csi-driver-nfs** (static PVs for existing libraries, dynamic StorageClass for new app data) | NAS is plain NixOS kernel NFS, not TrueNAS-API — democratic-csi's dynamic-ZFS-via-API value doesn't apply |
| Media egress | **Userspace Tailscale SOCKS5/HTTP proxy + pod label + default-deny-egress NetworkPolicy** | Drops all privilege/TUN; per-app opt-in with a leak-proof kill-switch |

### Why *not* democratic-csi

democratic-csi's headline feature is dynamically provisioning ZFS datasets/zvols
**through an API** (TrueNAS or SSH). The NAS exports plain kernel NFS
(`nixos/hosts/homelab-nas/shares.nix`), so that capability is unused. In generic
`nfs-client` mode democratic-csi is functionally equivalent to the simpler,
better-maintained `csi-driver-nfs`. Revisit only if the ZFS pool is later exposed via
the TrueNAS API or SSH-based dataset creation.

---

## 3. Target architecture

```
                          Internet
                             │
              *.bwees.io / *.starforgefoundry.com (wildcard A → VPS public IP)
                             │
                    ┌────────▼─────────┐
                    │   VPS cluster    │  k3s + Traefik(Gateway API) + cert-manager
                    │  (public entry)  │  public TLS via ACME DNS-01
                    │                  │  public HTTPRoutes generated at commit time (§7)
                    └────────┬─────────┘  (Host rewrite → internal name)
                             │  Tailscale (proxies to each node's Traefik)
        ┌────────────────────┼─────────────────────┬───────────────┐
        │                    │                     │               │
  ┌─────▼─────┐        ┌─────▼─────┐         ┌──────▼─────┐   ┌─────▼──────┐
  │ lab cluster│       │home cluster│        │stepien clst│   │ nas cluster│
  │ (main apps)│       │ (family)   │        │            │   │ (storage)  │
  │  k3s       │       │  k3s       │        │  k3s       │   │  k3s + ZFS │
  └─────┬──────┘       └────────────┘        └────────────┘   │  NFS export│
        │                                                     └─────▲──────┘
        │  csi-driver-nfs (RWX media libraries, app data)           │
        └───────────────────────────────────────────────────────────┘
                                NFS over Tailscale

  All clusters: Flux reconciles k8s/clusters/<name> from the monorepo.
```

- **NixOS** still owns the OS layer: disks, ZFS, Tailscale, the internal CA root cert,
  restic/sanoid backups, and now k3s itself.
- **k3s + Flux** own all workloads.
- **Ansible** shrinks to near-zero (the compose-push + env-render roles retire).

---

## 4. Cluster layer: k3s on NixOS

Each host swaps `nixos/lib/docker.nix` for a k3s module. Example:

```nix
# nixos/lib/k3s.nix
{ config, lib, ... }:
{
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik"          # we manage Traefik via Flux/Helm to control version + Gateway API
      "--disable=local-storage"    # replaced by csi-driver-nfs + local-path-provisioner (managed)
      "--write-kubeconfig-mode=0640"
      "--tls-san=${config.services.tailscale.ip}"
      "--node-ip=${config.services.tailscale.ip}"     # cluster traffic stays on Tailscale
      "--flannel-iface=tailscale0"
    ];
  };

  # k3s needs these open on the Tailscale interface for kubectl/flux access
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 6443 ];

  # Keep containerd's GC sane (mirrors the spirit of garbage-collect.nix)
  virtualisation.containerd.enable = lib.mkDefault true;
}
```

Notes:

- **GPU nodes** (`homelab-bwees` for Jellyfin/tdarr, `homelab-home` for Jellyfin):
  Intel iGPU `/dev/dri` is passed to pods via the
  [Intel GPU device plugin](https://github.com/intel/intel-device-plugins-for-kubernetes)
  (DaemonSet) or a simpler static `hostPath: /dev/dri` + `securityContext`. The device
  plugin is cleaner and schedulable.
- **NAS node**: k3s runs *alongside* ZFS/NFS/Samba already defined in NixOS. NFS server
  config is unchanged except widening the export (see §10).
- **etcd**: single-node k3s uses embedded SQLite — perfect for one-node-per-cluster, no
  etcd quorum concerns over the WAN.

Bootstrapping order per host: `nixos-rebuild` (brings up k3s) → copy kubeconfig →
`flux bootstrap` (see §5).

---

## 5. GitOps layer: Flux monorepo

Flux is **decentralized**: every cluster runs its own controllers and reconciles one
path. Shared building blocks are defined once and composed per cluster.

### Repo layout

```
k8s/
├── clusters/                     # one dir per cluster — `flux bootstrap --path` targets these
│   ├── lab/
│   │   ├── flux-system/          # generated by `flux bootstrap`
│   │   ├── infrastructure.yaml   # → ../../infrastructure/<controllers,configs>
│   │   └── apps.yaml             # → ../../apps/lab
│   ├── home/
│   ├── vps/
│   │   └── generated/            # ← GENERATED by the pre-commit hook (§7): public routes
│   ├── nas/
│   └── stepien/
│
├── infrastructure/
│   ├── controllers/              # HelmReleases: traefik, cert-manager, csi-driver-nfs,
│   │                             #   local-path-provisioner
│   └── configs/                  # ClusterIssuers, StorageClasses, GatewayClass, Gateways,
│                                 #   mullvad-proxy, base NetworkPolicies
│
├── apps/
│   ├── base/                     # per-app workload + ITS OWN route, co-located:
│   │   ├── immich/               #   deployment.yaml, service.yaml, pvc.yaml,
│   │   │                         #   secret.sops.yaml (§9), httproute.yaml (§7)
│   │   ├── jellyfin/
│   │   ├── sonarr/  radarr/  prowlarr/  qbittorrent/  ...
│   │   └── bind9/                #   (vps) mounts the GENERATED zone ConfigMap (§8)
│   ├── lab/                      # overlay: which apps run on lab + lab patches
│   ├── home/
│   ├── vps/
│   └── stepien/
│
├── components/                   # reusable Kustomize Components (the "define once" glue)
│   ├── mullvad-egress/           # label + NetworkPolicy + proxy env (§11)
│   └── nas-media/                # common NFS PV/PVC wiring (§10)
│
└── clusters.yaml                 # static map: cluster → ingress Tailscale IP (generator input)

scripts/gen-routing.*             # the generator run by the pre-commit hook (§7)
.pre-commit-config.yaml           # wires the generator + a stale-check
```

### Bootstrap a cluster (once per node)

```bash
export GITHUB_TOKEN=...           # or use a deploy key
flux bootstrap github \
  --owner=bwees --repository=homelab \
  --branch=main --path=k8s/clusters/lab \
  --components-extra=image-reflector-controller,image-automation-controller
```

### A cluster's composition pointers

```yaml
# k8s/clusters/lab/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: { name: infrastructure, namespace: flux-system }
spec:
  interval: 1h
  retryInterval: 2m
  path: ./k8s/infrastructure/controllers
  prune: true
  sourceRef: { kind: GitRepository, name: flux-system }
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: { name: infra-configs, namespace: flux-system }
spec:
  interval: 1h
  dependsOn: [{ name: infrastructure }]
  path: ./k8s/infrastructure/configs
  prune: true
  sourceRef: { kind: GitRepository, name: flux-system }
```

```yaml
# k8s/clusters/lab/apps.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata: { name: apps, namespace: flux-system }
spec:
  interval: 10m
  dependsOn: [{ name: infra-configs }]
  path: ./k8s/apps/lab
  prune: true
  sourceRef: { kind: GitRepository, name: flux-system }
  decryption:                         # SOPS for the bootstrap secrets (§9)
    provider: sops
    secretRef: { name: sops-age }
```

Each cluster differs only in *which* `apps/<cluster>` overlay it points at, so an app
defined once in `apps/base/<app>` is opted into per cluster.

---

## 6. Ingress: Traefik on Gateway API

Install Traefik via Helm with the Gateway API provider enabled, and install the Gateway
API CRDs.

```yaml
# k8s/infrastructure/controllers/traefik.yaml (HelmRelease excerpt)
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata: { name: traefik, namespace: traefik }
spec:
  interval: 1h
  chart:
    spec:
      chart: traefik
      sourceRef: { kind: HelmRepository, name: traefik, namespace: flux-system }
  values:
    providers:
      kubernetesGateway:
        enabled: true                 # Gateway API provider
      kubernetesIngress:
        enabled: false
    gateway:
      enabled: false                  # we declare our own Gateway (below) for clarity
    ports:
      web:        { port: 8000, expose: { default: true }, exposedPort: 80 }
      websecure:  { port: 8443, expose: { default: true }, exposedPort: 443 }
```

### GatewayClass + internal Gateway (shared config)

```yaml
# k8s/infrastructure/configs/gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata: { name: traefik }
spec:
  controllerName: traefik.io/gateway-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: internal, namespace: traefik }
spec:
  gatewayClassName: traefik
  listeners:
    - name: web
      protocol: HTTP
      port: 80
      allowedRoutes: { namespaces: { from: All } }
    - name: websecure
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs: [{ name: wildcard-bwees-lab }]   # from cert-manager (§8)
      allowedRoutes: { namespaces: { from: All } }
```

### App HTTPRoutes are co-located with the workload

Each app ships its own `HTTPRoute` next to its Deployment in `apps/base/<app>/`. It
declares the internal hostname and, optionally, a `homelab.bwees/public-host` annotation
for public exposure (§7). Each cluster's Flux applies its own internal routes against the
shared `internal` Gateway above; a pre-commit generator derives the cross-cluster bits
(public routes + DNS) from these same routes and commits them — see §7.

---

## 7. Routing — co-located declaration, commit-time generation

### The principle

**Routing lives next to the workload.** Each app ships its own `HTTPRoute` in
`apps/base/<app>/`, declaring its internal hostname and — if it should be public — a
`homelab.bwees/public-host` annotation. Each cluster's Flux applies its *own* internal
routes; there is no central routing file.

The two things that are *inherently* cross-cluster — **public routes** (all public traffic
enters one IP, the VPS, because home/stepien are NAT'd) and **DNS** — are **generated at
commit time** by a script run from a pre-commit hook. It reads every app's HTTPRoute, and
writes the VPS public routes and bind9 zones into the repo; Flux applies them like any other
manifest. So everything about an app stays in its folder; the cross-cluster wiring is
derived (committed alongside), not hand-authored — and there's no runtime component or
cross-cluster credential to operate.

### Co-located declaration

A public service (Immich on lab) and an internal-only service that happens to live on the
VPS (gatus) — both declared next to their Deployments:

```yaml
# k8s/apps/base/immich/httproute.yaml   (applied by the LAB cluster's Flux)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: immich
  namespace: immich
  labels:      { homelab.bwees/public: "true" }          # selector for the generator
  annotations: { homelab.bwees/public-host: immich.bwees.io }   # omit = internal-only
spec:
  parentRefs: [{ name: internal, namespace: traefik }]
  hostnames: ["immich.bwees.lab"]                        # internal name
  rules:
    - backendRefs: [{ name: immich-server, port: 2283 }]
```

```yaml
# k8s/apps/base/gatus/httproute.yaml    (applied by the VPS cluster's Flux)
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: gatus, namespace: monitoring }         # no public annotation
spec:
  parentRefs: [{ name: internal, namespace: traefik }]
  hostnames: ["status.bwees.lab"]                        # a .lab name that lives on the VPS
  rules:
    - backendRefs: [{ name: gatus, port: 8080 }]
```

### The generator (run by a pre-commit hook)

A script (`scripts/gen-routing.*`) renders each cluster's app overlay, collects every
HTTPRoute, and writes the derived cross-cluster artifacts into the repo. Rendering the
overlay (rather than scanning `apps/base`) is what tells the generator **which cluster owns
each route** — the overlay assignment is the single source of "what runs where," so the
route itself never has to name its cluster.

```
                 scripts/gen-routing.sh   (pre-commit)
                              │
   for cluster in lab home vps stepien starforge:
       kustomize build k8s/apps/$cluster | filter kind==HTTPRoute
       → collect (cluster, internalHost = .spec.hostnames[0],
                  publicHost = .metadata.annotations["homelab.bwees/public-host"])
                              │
        ┌─────────────────────┴───────────────────────────┐
        ▼                                                  ▼
  k8s/clusters/vps/generated/             k8s/apps/vps/bind9/zones-configmap.yaml
  public-routes.yaml                      (A records: internalHost → ingressIP[cluster])
  (ExternalName per cluster +
   public HTTPRoute per publicHost)
```

Generated VPS public routes (one `ExternalName` per distinct cluster, deduped; one
HTTPRoute per `publicHost`):

```yaml
# k8s/clusters/vps/generated/public-routes.yaml  — DO NOT EDIT (generated)
apiVersion: v1
kind: Service
metadata: { name: upstream-lab, namespace: public }
spec: { type: ExternalName, externalName: 100.65.90.4 }    # ingressIP[lab] from clusters.yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: immich-public, namespace: public }
spec:
  parentRefs: [{ name: public, namespace: traefik, sectionName: publicsecure }]
  hostnames: ["immich.bwees.io"]
  rules:
    - filters: [{ type: URLRewrite, urlRewrite: { hostname: immich.bwees.lab } }]
      backendRefs: [{ kind: Service, name: upstream-lab, port: 443 }]
```

The generator needs only one piece of static config — `k8s/clusters.yaml`, the cluster →
ingress-Tailscale-IP map — to fill in the ExternalName targets and the DNS records (§8).
Because it targets the cluster IP directly, the VPS does **not** need to resolve `.bwees.lab`
in-cluster (no CoreDNS forward required for public routing).

### The pre-commit hook (and a CI safety net)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: gen-routing
        name: generate routing + DNS
        entry: scripts/gen-routing.sh
        language: script
        pass_filenames: false
        files: ^k8s/apps/.*/httproute\.ya?ml$    # re-run when any route changes
```

The hook regenerates the files and `git add`s them, so the committed `generated/` output is
always in sync with the co-located routes. **Add the same generator as a CI check** (run it,
`git diff --exit-code` the generated paths) — pre-commit only runs locally, so the CI check
catches a route edited via the GitHub web UI or a commit that skipped the hook. Without it,
generated files could silently drift from source.

Traefik glue (unchanged): **Host rewrite** uses the Gateway API `URLRewrite` filter;
**backend TLS** (VPS→cluster HTTPS with the internal CA) uses a `BackendTLSPolicy` (SNI =
internalHost) or a Traefik `ServersTransport`; the **VPS public Gateway** has a
`public`/`publicsecure` listener bound to `45.137.192.163`, separate from the Tailscale-bound
private listener.

### Result

- **Everything about app X is in `apps/base/X/`** — workload *and* its route.
- **Expose publicly:** add the `public-host` annotation, commit (hook regenerates).
  **Unexpose:** remove it.
- **Move a service between clusters:** move its folder to the other cluster's overlay — the
  next commit regenerates its public route and DNS to match.
- **No runtime component, no cross-cluster credentials, bind9 stays static** — the only
  "magic" is a script in the repo you can read and run by hand.
- **Tradeoffs:** generated files live in git (review noise on each route change), and the
  CI stale-check is load-bearing — without it, a hook-less commit drifts. No single file
  lists all public services, but `grep`ping the `public-host` annotation (or reading
  `generated/public-routes.yaml`) is a decent inventory.

> Optional enhancement: the **Tailscale Kubernetes operator** can give each cluster's
> Traefik a stable MagicDNS name, so `clusters.yaml` holds names rather than hard-coded
> Tailscale IPs. Not required; revisit if IPs churn.

---

## 8. TLS & DNS

Replaces the static wildcard cert (`deploy/configs/traefik/vps/dynamic/certs.yml`) and
the CA baked in via `nixos/lib/root-ca.nix`.

### cert-manager

**Internal (`*.bwees.lab`, `*.bwees.home`)** — a `ClusterIssuer` backed by the existing
private CA, so every Gateway/HTTPRoute host gets a cert automatically:

```yaml
# k8s/infrastructure/configs/issuers.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: internal-ca }
spec:
  ca:
    secretName: bwees-internal-ca       # CA cert+key — a SOPS-encrypted Secret in git (§9)
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: { name: wildcard-bwees-lab, namespace: traefik }
spec:
  secretName: wildcard-bwees-lab
  issuerRef: { name: internal-ca, kind: ClusterIssuer }
  dnsNames: ["*.bwees.lab", "bwees.lab"]
```

NixOS keeps distributing the CA **root** to clients via `root-ca.nix` (unchanged), so
internal HTTPS stays trusted.

**Public (`*.bwees.io`, `starforgefoundry.com`)** — ACME with **DNS-01** on the VPS
cluster, giving real browser-trusted certs (an improvement; today public hosts appear to
reuse the internal cert):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: { name: letsencrypt }
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef: { name: letsencrypt-account }
    solvers:
      - dns01:
          # provider for whoever hosts bwees.io public DNS (e.g. Cloudflare)
          cloudflare:
            apiTokenSecretRef: { name: cloudflare-token, key: token }
```

### DNS — generated zones, records follow the cluster that hosts each service

bind9 stays the authoritative split-DNS server for `bwees.lab` / `bwees.home`, and — because
generation happens at commit time — it stays **static zone files** (no dynamic TSIG). The
same `gen-routing` generator (§7) that knows each route's owning cluster also writes the
internal A records, mapping `internalHost → ingressIP[cluster]` from `clusters.yaml`.

This solves the correctness issue your VPS `.bwees.lab` services raised: gatus
`status.bwees.lab` and `beszel.bwees.lab` live on the **VPS**, not the lab host. Their
HTTPRoutes are in the VPS overlay, so the generator emits `status.bwees.lab → VPS IP` and
`immich.bwees.lab → lab IP` automatically — retiring the hand-maintained per-host overrides
in `deploy/configs/dns/vps/bwees.lab.zone`.

```yaml
# k8s/apps/vps/bind9/zones-configmap.yaml  — DO NOT EDIT (generated); bind9 mounts it
apiVersion: v1
kind: ConfigMap
metadata: { name: bind-zones, namespace: dns }
data:
  bwees.lab.zone: |
    $TTL 300
    @ IN SOA . root.bwees.lab. ( 2026053001 604800 86400 2419200 604800 )  # serial = content hash
      IN NS .
    immich  IN A 100.65.90.4      ; cluster: lab
    git     IN A 100.65.90.4      ; cluster: lab
    status  IN A 100.105.77.106   ; cluster: vps   ← VPS-hosted .lab service, correct target
    beszel  IN A 100.105.77.106   ; cluster: vps
    ; ... plus a committed base block of static infra records (nas, router/unifi) + wildcard
```

The bind9 Deployment mounts the ConfigMap; a checksum annotation on its pod template
triggers a reload when records change, and the generator sets the SOA serial from a content
hash so it bumps only on real changes.

- An explicit A record is **more specific than `*`**, so generated per-service records win
  over a `*.bwees.lab → lab` wildcard exactly as the manual overrides do today. Keep the
  wildcard as a fallback or drop it for full explicitness.
- Static infrastructure records (nas, router/unifi) and the SOA/NS live in a small committed
  base block the generator concatenates with (or `$INCLUDE`s into) the generated records.
- **Public DNS** (`*.bwees.io → VPS`) is a one-time wildcard, so no per-service public record
  is needed; the generator can also emit explicit `bwees.io` records if you host that zone on
  a provider you control and want them.
- Non-cluster backends (e.g. the private `sfcam` at `100.125.29.116:5000`) are declared as an
  HTTPRoute → `ExternalName` so they flow through the same generator, or kept as a small
  static Traefik route on the VPS.
- Tailscale split-DNS config (`tailscale/dns.json`) is unchanged.

---

## 9. Secrets: SOPS + age (all-in)

**Model:** every secret is a SOPS-encrypted Kubernetes `Secret` committed to git, decrypted
by Flux's kustomize-controller at apply time using an `age` key held in-cluster. **No
1Password, no External Secrets Operator, no runtime secret service** — git is the source of
truth and the only moving part is Flux's built-in decryption. Edit with the **VS Code SOPS
extension** (transparent decrypt-on-open / encrypt-on-save) or the `sops` CLI.

### Key strategy (multi-cluster)

Use **one age key per cluster** plus your **personal admin key**. Every secret is encrypted
to (its owning cluster's public key + your admin key), so:

- each cluster can only decrypt the secrets meant for it (blast-radius isolation — a
  compromised home-cluster key can't read lab secrets), and
- you can decrypt/edit any secret locally with your admin key.

`.sops.yaml` path rules pick the recipients automatically based on where a file lives:

```yaml
# .sops.yaml (repo root)
creation_rules:
  - path_regex: k8s/(apps|clusters|infrastructure)/.*lab.*\.sops\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1ADMIN...,        # your personal key (can edit everything)
      age1LABCLUSTER...    # lab cluster's key
  - path_regex: k8s/(apps|clusters|infrastructure)/.*home.*\.sops\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: age1ADMIN...,age1HOMECLUSTER...
  # ...one rule per cluster; shared/infra secrets list every cluster key
```

> Simpler alternative: a **single shared age key** for all clusters — one `.sops.yaml` rule,
> any cluster decrypts anything. Less isolation, less ceremony. Fine if you'd rather not
> juggle per-cluster keys.

### Per-cluster decryption

`flux bootstrap` doesn't manage the key — you create the `sops-age` Secret once per cluster
(out-of-band; it's the key that *decrypts* git, so it can't live in git):

```bash
kubectl create secret generic sops-age -n flux-system \
  --from-file=age.agekey=./<cluster>.agekey
```

Flux Kustomizations already reference it (set in §5):

```yaml
spec:
  decryption: { provider: sops, secretRef: { name: sops-age } }
```

### A secret, co-located with its app (replaces `${IMMICH_DB_PASSWORD}` env files)

The encrypted `Secret` lives next to the workload, just like its route (§7). Only the
*values* are ciphertext; keys/structure stay readable so diffs are meaningful:

```yaml
# k8s/apps/lab/immich/secret.sops.yaml   (committed; values encrypted)
apiVersion: v1
kind: Secret
metadata: { name: immich-db, namespace: immich }
stringData:
  IMMICH_DB_PASSWORD: ENC[AES256_GCM,data:9f3...,type:str]
sops: { age: [...recipients...], lastmodified: "...", mac: "..." }
```

```yaml
# referenced normally in the Deployment
env:
  - name: DB_PASSWORD
    valueFrom: { secretKeyRef: { name: immich-db, key: IMMICH_DB_PASSWORD } }
```

Everything else that was an env-file value or a 1Password item — Tailscale auth keys
(`ts-authkey`), the internal CA key (`bwees-internal-ca`), the cert-manager DNS-01 token,
Beszel keys, n8n runner secret, etc. — becomes a SOPS-encrypted `Secret` the same way. This
retires the Ansible `op item get` → env-file render flow and the 1Password CLI entirely.

### Tradeoffs vs. a live secret store

- **You own the lifecycle.** Generating, rotating, and pasting secret values is manual
  (`sops` edit + commit) — there's no live sync from an external vault. For a homelab that's
  usually fine and is the price of zero runtime dependencies.
- **Encrypted material lives in git history.** SOPS protects values at rest, but if an age
  *private* key ever leaks, anyone with the repo (and git history) can decrypt every secret
  that key was a recipient of — including old ciphertext. So **treat a key leak as requiring
  rotation of both the key and the secrets**, and back the age private keys up somewhere safe
  and offline (a password manager or hardware-backed store — keeping them out of the cluster
  config). Losing *all* copies of a cluster's key makes its secrets unrecoverable.

---

## 10. Storage: csi-driver-nfs

Install via Helm in `infrastructure/controllers`. Two usage patterns.

### (a) Existing libraries → static PV/PVC

Maps the exact subpaths mounted today in `deploy/compose/lab/media.yml`
(`tv`, `movies`, `audiobooks`, `tdarr-cache`, `qbt`):

```yaml
# k8s/components/nas-media/pv-tv.yaml
apiVersion: v1
kind: PersistentVolume
metadata: { name: nas-media-tv }
spec:
  capacity: { storage: 1Ti }            # required by API, ignored by NFS
  accessModes: [ReadWriteMany]
  persistentVolumeReclaimPolicy: Retain
  csi:
    driver: nfs.csi.k8s.io
    volumeHandle: nas-media-tv
    volumeAttributes:
      server: nas.bwees.lab
      share: /mnt/main/homelab/media/tv
  mountOptions: [nfsvers=4, nolock, soft]
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: media-tv, namespace: media }
spec:
  accessModes: [ReadWriteMany]
  storageClassName: ""                  # static binding
  volumeName: nas-media-tv
  resources: { requests: { storage: 1Ti } }
```

### (b) New per-app data → dynamic StorageClass

```yaml
# k8s/infrastructure/configs/storageclass-nfs.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: nas-nfs }
provisioner: nfs.csi.k8s.io
parameters:
  server: nas.bwees.lab
  share: /mnt/main/homelab/k8s-volumes   # driver auto-creates a subdir per PVC
mountOptions: [nfsvers=4, nolock, soft]
reclaimPolicy: Retain
```

### (c) Local app state → local-path-provisioner

Config dirs and **databases** that live on the node's fast local disk today
(`/storage/<app>`, immich Postgres, gitea-mirror SQLite) stay local. Use k3s
`local-path-provisioner` (managed via Flux) or static `hostPath` PVs pointing at
`/storage/<app>`. **Do not put Postgres on NFS.**

### NixOS NFS change

The export is currently locked to one client IP
(`192.168.50.173`, `nixos/hosts/homelab-nas/shares.nix`). Widen it to the Tailscale
CGNAT range (or each node's Tailscale IP) so pods on every cluster can mount:

```nix
# shares.nix (illustrative)
exports = ''
  /mnt/main/homelab  100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash,fsid=0)
'';
```

(Pin to specific node Tailscale IPs if you want tighter scoping.)

---

## 11. Media stack: SOCKS5 egress + NetworkPolicy kill-switch

Replaces the privileged kernel-mode `exitnode` + `network_mode: service:exitnode` pattern
in `deploy/compose/lab/media.yml`.

### The proxy (userspace — no TUN, no privilege)

```yaml
# k8s/infrastructure/configs/mullvad-proxy.yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: mullvad-proxy, namespace: egress }
spec:
  replicas: 1
  selector: { matchLabels: { app: mullvad-proxy } }
  template:
    metadata: { labels: { app: mullvad-proxy } }
    spec:
      containers:
        - name: tailscale
          image: tailscale/tailscale:v1.98.4
          env:
            - { name: TS_USERSPACE,                  value: "true" }          # no /dev/net/tun, no NET_ADMIN
            - { name: TS_SOCKS5_SERVER,              value: "0.0.0.0:1055" }
            - { name: TS_OUTBOUND_HTTP_PROXY_LISTEN, value: "0.0.0.0:1056" }  # HTTP proxy for apps that prefer it
            - { name: TS_EXTRA_ARGS,                 value: "--exit-node=100.82.151.77 --exit-node-allow-lan-access" }
            - { name: TS_STATE_DIR,                  value: "/var/lib/tailscale" }
            - name: TS_AUTHKEY
              valueFrom: { secretKeyRef: { name: ts-authkey, key: authkey } }   # SOPS secret (§9)
          ports:
            - { name: socks5,     containerPort: 1055 }
            - { name: httpproxy,  containerPort: 1056 }
          volumeMounts: [{ name: state, mountPath: /var/lib/tailscale }]
      volumes: [{ name: state, persistentVolumeClaim: { claimName: mullvad-state } }]
---
apiVersion: v1
kind: Service
metadata: { name: mullvad-proxy, namespace: egress }
spec:
  selector: { app: mullvad-proxy }
  ports:
    - { name: socks5,    port: 1055 }
    - { name: httpproxy, port: 1056 }
```

### "Join the mullvad network" = label + NetworkPolicy (reusable Component)

```yaml
# k8s/components/mullvad-egress/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component
patches:
  - target: { kind: Deployment }
    patch: |-                                  # stamp the label on whatever Deployment uses this component
      - op: add
        path: /spec/template/metadata/labels/egress
        value: mullvad
resources:
  - networkpolicy.yaml
```

```yaml
# k8s/components/mullvad-egress/networkpolicy.yaml
# 1) Default-deny egress for labeled pods → only the proxy + DNS reachable = kill-switch
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: mullvad-default-deny-egress }
spec:
  podSelector: { matchLabels: { egress: mullvad } }
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: egress } }
          podSelector: { matchLabels: { app: mullvad-proxy } }
      ports: [{ port: 1055 }, { port: 1056 }]
    - ports: [{ port: 53, protocol: UDP }, { port: 53, protocol: TCP }]   # cluster DNS only
---
# 2) Proxy only ACCEPTS labeled pods (it is unauthenticated)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: mullvad-proxy-ingress, namespace: egress }
spec:
  podSelector: { matchLabels: { app: mullvad-proxy } }
  policyTypes: [Ingress]
  ingress:
    - from: [{ podSelector: { matchLabels: { egress: mullvad } } }]
```

> k3s enforces NetworkPolicy out of the box via its bundled kube-router controller, so
> this works without changing the CNI.

### An app opts in (e.g. Sonarr)

```yaml
# k8s/apps/base/sonarr/kustomization.yaml
resources: [deployment.yaml, service.yaml, httproute.yaml, pvc.yaml]
components:
  - ../../../components/mullvad-egress    # adds label + NetworkPolicy
```

```yaml
# k8s/apps/base/sonarr/deployment.yaml (excerpt)
spec:
  template:
    spec:
      containers:
        - name: sonarr
          image: ghcr.io/linuxserver/sonarr:4.0.17
          env:
            - { name: HTTP_PROXY,  value: "http://mullvad-proxy.egress:1056" }
            - { name: HTTPS_PROXY, value: "http://mullvad-proxy.egress:1056" }
```

### Per-app proxy notes (important trade-off)

SOCKS5/HTTP proxy is **per-application opt-in** — unlike today's shared netns, the app
must be told to use it. The NetworkPolicy is the safety net: even if an app ignores the
proxy, it can only reach the proxy + DNS, so **there is no clearnet leak**.

| App | Proxy support | Notes |
|---|---|---|
| qBittorrent | ✅ native SOCKS5 in Connection settings | Point at `mullvad-proxy.egress:1055` |
| Sonarr / Radarr / Prowlarr | ✅ proxy in Settings → General | HTTP or SOCKS5 |
| flaresolverr | ⚠️ accepts a proxy | configure via env |
| shelfarr / others w/o proxy setting | ⚠️ | add a `redsocks` sidecar for transparent redirect, or rely on the kill-switch + accept it can't egress |

Apps that should **not** egress via Mullvad (Jellyfin, tdarr, seerr, audiobookshelf)
simply omit the component/label and route normally — cleaner separation than today's
monolithic netns.

---

## 12. Cross-cutting: monitoring, backups, images, renovate

- **Monitoring (beszel):** agents are host-level — keep them in NixOS (systemd) or run as
  a DaemonSet. The beszel hub can move to the VPS cluster. Add kube-state-metrics later if
  desired.
- **Backups (restic, sanoid, ZFS):** stay at the NixOS layer (they back up `/storage` and
  ZFS datasets — `nixos/lib/restic-copies.nix`, `sanoid.nix`, `zfs-backup.nix`). Point
  them at the new local-path PV directories under `/storage`.
- **Custom images:** the GitHub Actions → ghcr flow (`.github/workflows/deploy.yml`,
  `just build-custom-images`) is unchanged for *building*. Optionally add Flux
  **image-automation** to auto-bump your own image tags (n8n-runner, crosshatch,
  photoframe, cah-discord) via PRs.
- **Renovate:** keep it — it understands Flux `HelmRelease`, Kustomize, and raw k8s
  manifests, not just compose. Update `renovate.json` managers to point at `k8s/`.
- **Ansible:** the `deploy_host` role (compose push + env render) retires. The CI deploy
  job is replaced by Flux reconciliation; the Tailscale ACL/DNS job (`tailscale/apply.sh`)
  stays as-is.

---

## 13. Per-service migration map

| Current (compose) | Target cluster | Storage | Public? | Egress |
|---|---|---|---|---|
| traefik (lab/home) | each | — | — | ingress controller |
| immich (server/ml/redis/db) | lab | NFS lib + local-path PG | yes (`immich.bwees.io`) | normal |
| gitea + gitea-mirror | lab | NFS (gitea) + local-path | no | normal |
| n8n + n8n-runner | lab | local-path | yes (`n8n.bwees.io`) | normal |
| changedetection + sockpuppet | lab | local-path | no | normal |
| wakapi, psitransfer, cah, crosshatch | lab | local-path / NFS | transfer=yes | normal |
| jellyfin (lab) | lab | NFS tv/movies + local cfg, `/dev/dri` | yes | normal |
| tdarr, seerr, audiobookshelf | lab | NFS + local | no | normal |
| qbittorrent | lab | NFS qbt + downloads | via VPS only | **mullvad** |
| radarr, sonarr, prowlarr | lab | NFS movies/tv + downloads | internal | **mullvad** |
| flaresolverr, shelfarr | lab | local / NFS audiobooks | internal | **mullvad** |
| jellyfin, hass, photoframe, bind9 (home) | home | NFS media + local | album/hass=yes | normal |
| immich + stepien apps | stepien | NFS/local | stepien-immich=yes | normal |
| traefik, gatus, bind9, postgres, portainer, beszel, readme-stats (vps) | vps | local-path | gatus/portainer/stats=yes | public entry |
| restic-server, beszel-agent (nas) | nas | ZFS | no | normal |

---

## 14. Phased rollout

Lowest-risk order — each phase is independently revertible:

1. **VPS cluster (pilot).** Smallest, most self-contained. Stand up k3s + Flux + Traefik
   (Gateway API) + cert-manager + SOPS decryption. Migrate gatus/portainer/beszel.
   Build and prove the gen-routing pre-commit generator + Host-rewrite path end-to-end.
2. **Storage layer.** Deploy csi-driver-nfs; validate static + dynamic NFS mounts from the
   VPS cluster against the NAS over Tailscale; widen the NFS export.
3. **Lab cluster.** The big migration: immich (incl. local-path Postgres), gitea, n8n,
   etc. Stand up the **mullvad-proxy + NetworkPolicy** and migrate the *arr stack onto it.
   Validate the per-app proxy + kill-switch.
4. **Home + Stepien clusters.** Replicate using shared `apps/base` + overlays. Mind the
   GPU device plugin on home (Jellyfin).
5. **Decommission.** Remove Docker from NixOS hosts, retire the Ansible `deploy_host`
   role, and delete the hand-maintained `deploy/configs/traefik/vps/dynamic/public.yml`.

---

## 15. Risks & things to validate

- **k3s Gateway API maturity in Traefik** — confirm the Traefik chart version's Gateway
  API support covers `URLRewrite` (hostname) and `BackendTLSPolicy`; fall back to Traefik
  `Middleware`/`ServersTransport` CRDs if a feature is still experimental.
- **Generator drift (§7)** — pre-commit runs only locally, so a route edited via the GitHub
  web UI or a hook-less commit can leave `generated/` stale. The **CI stale-check is
  load-bearing** (run the generator, `git diff --exit-code`); treat it as required, not
  optional. Cover create/update/**delete** of routes (a removed `public-host` must remove the
  generated route, and Flux `prune` must clean it up).
- **Generator must handle deletes + pruning** — when an app or its `public-host` is removed,
  the generator should drop the corresponding entries and Flux's `prune: true` on the VPS
  Kustomization removes the orphaned objects. Verify orphan cleanup end-to-end.
- **bind9 reload on ConfigMap change** — confirm the checksum-annotation rollout actually
  reloads zones and the SOA serial bumps only on real changes (content hash), so stale
  records don't linger.
- **SOCKS5 kill-switch correctness** — verify with a leak test (force-disable the proxy in
  an app and confirm it cannot reach the internet) before trusting it for torrent traffic.
  Validate Tailscale userspace mode + `--exit-node` actually egresses via Mullvad.
- **NFS + databases** — keep Postgres/SQLite on local-path; NFS-backed DBs corrupt. Verify
  `no_root_squash` / UID mapping still matches the `PUID=1000/PGID=1000` apps use today.
- **age key custody (§9)** — losing all copies of a cluster's age private key makes its
  secrets unrecoverable; a leaked key exposes all secrets it can decrypt (incl. git history).
  Back keys up offline, scope per-cluster, and have a rotation runbook (re-encrypt + rotate
  the underlying secret values).
- **Bootstrap chicken-and-egg** — the `sops-age` key and initial kubeconfig are the only
  truly manual per-cluster steps; document them in the runbook.
- **GPU scheduling** — validate Intel `/dev/dri` access for Jellyfin/tdarr under the device
  plugin (transcoding is the main regression risk).
- **WAN reconciliation** — Flux on the home/stepien clusters reconciles over the public
  internet to GitHub (not dependent on Tailscale), so a Tailscale outage doesn't stop
  GitOps; confirm image pulls and NFS (which *do* use Tailscale) degrade gracefully.
