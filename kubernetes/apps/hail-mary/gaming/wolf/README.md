# Wolf (Moonlight game streaming)

[Wolf](https://github.com/games-on-whales/wolf) runs as a single pod pinned to
**xenonite** (the AMD-GPU node) and launches each game/app as a **Docker container on
xenonite's `dockerd`** via the mounted docker socket. A k8s pod (containerd) and
`dockerd` share the same kernel/filesystem on the node, so the host paths Wolf hands to
Docker for bind-mounts stay consistent.

This is deliberately *not* the [Fenrir](https://github.com/games-on-whales/fenrir)
operator: Fenrir only emits shared-IP `LoadBalancer` Services (needs MetalLB/Cilium),
advertises the ClusterIP to Moonlight, and is a single-session POC. Running Wolf in its
native docker-launching mode avoids all of that.

## Access — the `wolf` tailscale device

The Service is exposed as a dedicated tailnet device named `wolf` via the tailscale
operator (`tailscale.com/expose` + `tailscale.com/hostname: wolf`) — the same L3
TCP/UDP DNAT mechanism as the PowerDNS `dns` device. One device carries **both**
pairing (47984/47989) and streaming (48010 TCP, 47999/48100/48200 UDP), so Moonlight's
"stream IP must equal pairing IP" requirement is satisfied automatically. No
LoadBalancer, no MetalLB, no hostNetwork, no host-firewall changes.

Pair Moonlight against `wolf.<tailnet>.ts.net`, then approve via the pairing PIN/URL:

```sh
kubectl -n gaming logs deploy/wolf
```

## Config (in-repo, pairings preserved)

Wolf reads `config.toml` once at startup and **rewrites it in place when a client
pairs** (`paired_clients`), and has no include mechanism. So:

- `app/config.toml` (seeded from Wolf's upstream `config.v7.toml`) is the in-repo source
  of truth, delivered as the `wolf-config` ConfigMap (mounted read-only at
  `/cfg-src/config.toml`).
- The `merge-config` initContainer renders the live `/etc/wolf/cfg/config.toml` on the
  `/etc/wolf` hostPath = repo config **+** the `paired_clients` preserved from the
  previous live file (via `dasel`). First run seeds; a failed merge reseeds so Wolf
  always starts.

To change available apps: edit `app/config.toml`, reconcile, then
`kubectl -n gaming rollout restart deploy/wolf`. Paired clients survive.

## Node requirements (xenonite)

`nixos/hosts/hail-mary/xenonite/configuration.nix` imports `lib/docker.nix` (dockerd +
`/var/run/docker.sock`) and `lib/amd-gpu.nix` (amdgpu + mesa). Apply with
`mise run nixos:switch xenonite`.

## Why the pod is privileged

Wolf needs `/dev/dri` (encode), `/dev/uinput` + `/dev/uhid` (virtual input), the device
cgroup rule, and the docker socket — hence `privileged: true` and the hostPath mounts of
`/dev`, `/run/udev`, `/var/run/docker.sock`, `/etc/wolf` (state), and `/run/user/wolf`
(runtime sockets, bind-mounted into the launched app containers). Effectively root on
xenonite — acceptable for a homelab.
