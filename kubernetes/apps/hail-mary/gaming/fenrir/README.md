# Fenrir (Wolf on Kubernetes)

[Fenrir](https://github.com/games-on-whales/fenrir) orchestrates multiple
[Wolf](https://github.com/games-on-whales/wolf) game-streaming instances on
Kubernetes. Moonlight clients connect to a `moonlight-proxy`, which the operator
uses to launch per-session pods (game container + Wolf encoder + wolf-agent +
pulseaudio, all in one pod sharing `XDG_RUNTIME_DIR`).

## ⚠️ Status: proof-of-concept

Upstream states Fenrir is **not in a usable state**. Known limitations baked into
this deployment:

- **Single active session at a time** — port-forwarding is the "lynchpin" and
  currently only supports one session.
- **User is hardcoded to `alex`** — do not rename it (`user.yaml`).
- **Per-session Wolf ports are unsolved here** — the operator provisions the
  session's RTSP/RTP/ENET (UDP) ports as a MetalLB/Cilium shared-IP
  LoadBalancer. This cluster runs neither, so those services will not get an IP.
  Only the `moonlight-proxy` pairing ports are wired up (via tailscale, below).
  Solving streaming ports needs Gateway API `UDPRoute`/a relay per upstream's
  own notes.

## What is deployed

- `crds/` — the four Fenrir CRDs (`apps`, `pairings`, `sessions`, `users`),
  vendored because the Helm chart does not ship them.
- `ocirepository.yaml` + `helmrelease.yaml` — the `direwolf-operator` chart
  (operator + moonlight-proxy + cert-manager self-signed CA for internal TLS).
- `user.yaml` — the `alex` User, requesting the AMD GPU via `squat.ai/dri`.
- `firefox.yaml` — a sample streamable App to test the pipeline.

## Ingress (tailscale)

The `moonlight-proxy` Service is exposed as a dedicated tailnet device named
`wolf` using the tailscale operator (`tailscale.com/expose` + `hostname`), the
same L3-DNAT mechanism as the `dns` PowerDNS device. Pair Moonlight against
`wolf.<tailnet>.ts.net` (ports 47984/47989). This replaces the upstream
MetalLB/Cilium shared-IP LoadBalancer.

## GPU node

Sessions are pinned to the GPU node **implicitly**: the `generic-device-plugin`
(`kubernetes/components/amd-gpu/`) only runs on the node labeled
`lab.bwees/role=gpu`, so `squat.ai/dri` exists only there and any pod requesting
it schedules there. Fenrir's CRDs have no `nodeSelector`/`toleration` fields, so
this is the mechanism — **do not taint the GPU node** (session pods can't
tolerate it and would be unschedulable).

To bring up the AMD GPU node (a new k3s member of hail-mary):

1. Create `nixos/hosts/hail-mary/<name>/` (copy an existing joining node like
   `rocky` for `hardware-configuration.nix` / `disk-config.nix`).
2. Import `../../../lib/amd-gpu.nix` and `../../../lib/k3s-multinode.nix`.
3. Join the cluster and label the node:

   ```nix
   services.k3s.serverAddr = "https://192.168.50.110:6443";
   services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";
   services.k3s.extraFlags = [ "--node-label=lab.bwees/role=gpu" ];
   ```

Intel nodes can later host their own independent sessions the same way — point
a `generic-device-plugin` at their `/dev/dri/renderD128`. Note Wolf renders and
encodes in the *same* pod on *one* node; a single session cannot render on the
GPU node and encode elsewhere.

## Pairing

```sh
# Moonlight pairs to wolf.<tailnet>.ts.net, then grab the pairing URL:
kubectl logs -n gaming deploy/moonlight-proxy
```
