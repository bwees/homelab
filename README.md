# Homelab

This repository houses the infrastructure configuration for my homelab. The entire stack is managed with GitOps, and the repository is the single source of truth for all configuration. The tools to accomplish this are:

- **NixOS** provisions and configures every machine. Updates are manually applied.
- **Kubernetes** (k3s) runs the applications, managed with Flux via GitOps.
- **OpenTofu** manages the external services used by the homelab (Cloudflare, Tailscale, and 1Password).

## NixOS

Every node runs NixOS, defined in [nixos/](nixos/). Each host has its own directory under [nixos/hosts/](nixos/hosts/), and shared functionality lives in reusable modules under [nixos/lib/](nixos/lib/) (k3s, Tailscale, Docker, Longhorn prerequisites, backups, garbage collection, and so on). The [flake](nixos/flake.nix) wires each host configuration into a `nixosConfiguration`.

Nodes are partitioned with Disko and can be provisioned from scratch using nixos-anywhere. Once a machine is up, configuration changes are pushed with `nixos-rebuild switch`. Both of these are wrapped as mise tasks:

```bash
mise run nixos:anywhere <host> <ip>   # provision a new machine from scratch
mise run nixos:switch <host>          # apply configuration changes
```

See [nixos/README.md](nixos/README.md) for more detail on disk layout and hardware configuration.

## Kubernetes

Applications run on k3s clusters that are managed entirely through GitOps with Flux. When I push to `main`, Flux reconciles the cluster to match the repository.

The manifests in [kubernetes/](kubernetes/) are organized as:

- [kubernetes/clusters/](kubernetes/clusters/) - the Flux entrypoint for each cluster. This is what Flux watches and reconciles.
- [kubernetes/apps/](kubernetes/apps/) - the applications, grouped by cluster.
- [kubernetes/components/](kubernetes/components/) - reusable pieces (for example a PostgreSQL cluster and volsync backup config) that apps pull in.

I run several clusters, each with a different purpose:

- **eridani** - a small node at my parent's house.
- **hail-mary** - a multi-node HA cluster (grace, rocky, xenonite, astrophage) running the majority of my services.
- **stepien** - a small node at my grandparent's house, specifically for Immich.
- **tau-ceti** - a VPS that currently handles monitoring.

A few things worth calling out about the cluster setup:

- **Storage** is handled by Longhorn, with volsync taking scheduled backups of persistent volumes.
- **Secrets** come from 1Password through External Secrets.
- **Flux** is installed by flux-operator from a `FluxInstance`, not by `flux bootstrap`. The `mise run bootstrap <host> [cluster]` task seeds the 1Password service account token, registers a git deploy key, installs the operator and applies the cluster's `FluxInstance`.
- **Databases** run on CloudNative-PG.
- **Ingress** is served through Envoy Gateway, with cert-manager issuing certificates.

## Networking

Tailscale is used for all private networking between nodes and clients. Public traffic is routed via Cloudflare Tunnels, which forward requests into the cluster without exposing any inbound ports.

I run two domains:

- `bwees.io` - public services, fronted by Cloudflare.
- `bwees.dev` - everything internal. `*.bwees.dev` is personal services and `*.home.bwees.dev` is family services.

Both zones live in Cloudflare. Kubernetes external-dns writes every `bwees.dev` record straight into the zone, so the names resolve publicly even though they point at addresses that are only reachable over Tailscale or on the LAN. That keeps DNS-01 available for real Let's Encrypt certificates on internal services, so there is no private CA to distribute.

`bwees.io` is the exception: its public wildcard points at `tau-ceti`, which forward-proxies by SNI to whichever cluster owns the hostname. Resolving that needs a split-horizon view, which is a static `hosts` block in `tau-ceti`'s CoreDNS - adding a `bwees.io` route means adding an entry there too.

## OpenTofu

The external services that live outside of Kubernetes are managed with OpenTofu in [tofu/](tofu/). This currently covers:

- **Cloudflare** - Zero Trust tunnels and the public DNS records that point at them.
- **Tailscale** - ACLs, DNS preferences, nameservers, and split DNS configuration.
- **1Password** - storing generated secrets (such as tunnel tokens) back into the vault so the clusters can consume them.

State is stored in a Cloudflare R2 bucket, and all provider credentials are pulled from 1Password at plan/apply time.

## CI/CD

The [deploy workflow](.github/workflows/deploy.yml) runs on every push to `main` and applies the changes from OpenTofu.
