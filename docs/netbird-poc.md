# NetBird PoC: replacing Tailscale, with AirVPN as the exit node

Branch `poc/netbird`. Everything Tailscale is gone from the repo: the operator and
its ProxyGroups, the `tailscale.com/*` Service annotations, the media SOCKS5 pod,
qbittorrent's Mullvad sidecar, the NixOS modules, and `tofu/config/tailscale.tf`.
Mullvad is replaced by an in-cluster AirVPN exit node.

## What replaces what

| Tailscale | NetBird |
| --- | --- |
| `tailscale-operator` + `ProxyGroup` | `netbird-operator` + `SidecarProfile` |
| `tailscale.com/expose` on a Service | a client injected into the pod |
| `tailscale.com/hostname` / VIPService | `extraDNSLabels` on the profile |
| `tag:*` from `--advertise-tags` | groups from a setup key's `autoGroups` |
| `--advertise-routes`, `--advertise-exit-node` | `netbird_route` (Tofu) |
| Mullvad exit node in the tailnet | gluetun + AirVPN pod holding `0.0.0.0/0` |
| `tailscale_acl` | `netbird_policy` + route access-control groups |
| `<name>.tail72746.ts.net` | `<name>.netbird.cloud` |

The shape of the change: a Tailscale device sat *in front of* a workload and DNAT-ed
into it. NetBird's operator puts the client *inside* the pod, so the workload owns
its peer address. That removes the proxy hop, the static-endpoint NodePorts on
tau-ceti, and every pinned `100.x` address in the repo.

## Ingress, and why nothing pins an address any more

`SidecarProfile/envoy-ingress` matches `lab.bwees/netbird: ingress` (stamped on the
envoy pod template by the existing `EnvoyProxy` patch) and gives each replica the
extra DNS label `<cluster>-ingress`. NetBird emits one A record per peer holding a
label, so two envoy replicas on hail-mary answer `hail-mary-ingress.netbird.cloud`
round-robin - the HA that `ProxyGroup: replicas: 2` used to provide.

Injected clients keep state in an `emptyDir`, so a restarted pod is a *new* peer
with a new address. Their setup key is therefore `ephemeral: true` (NetBird reaps
the dead peer after 10 minutes offline) and both DNS paths target the label:

- `external-dns` → Gateway annotation `${CLUSTER}-ingress.netbird.cloud` (now in
  `apps/base`, so hail-mary, stepien and tau-ceti no longer carry a hardcoded IP).
- `external-dns-bind` → `--default-targets=${CLUSTER}-ingress.netbird.cloud`.

eridani still overrides the target with `10.0.1.2`: `*.home.bwees.dev` has one
public answer and family devices reach it off-mesh.

## The AirVPN exit node

`apps/hail-mary/networking/airvpn-exit` is one pod, two containers, one netns:

- **gluetun** (`VPN_SERVICE_PROVIDER=airvpn`) owns the default route and sets every
  iptables policy to `DROP`, so a dropped tunnel kills egress instead of leaking.
- **the NetBird client** advertises `0.0.0.0/0` (the `netbird_route.airvpn_exit`
  Tofu resource, distributed to the `vpn-clients` group).

Three details make this work, and each one is load-bearing:

1. **Port forwarding is not optional.** The client's own control-plane and
   WireGuard traffic rides the AirVPN tunnel, so peers see it at AirVPN's egress
   address. `NB_WIREGUARD_PORT` is set to the port reserved in the AirVPN client
   area and handed to gluetun as `FIREWALL_VPN_INPUT_PORTS`. Match them and peers
   connect directly; mismatch them and it still works, but every byte is relayed
   through NetBird's infrastructure.
2. **gluetun's firewall does not know about `wt0`.** It rebuilds its rules on each
   reconnect and runs `/iptables/post-rules.txt` afterwards, so the mesh's holes
   live in that ConfigMap: `wt0` in/out, and forwarding both ways between `wt0` and
   `tun0`. Everything else stays denied.
3. **Cluster CIDRs must bypass the tunnel.** `FIREWALL_OUTBOUND_SUBNETS` keeps
   `10.42.0.0/16,10.43.0.0/16` on `eth0`.

## Media egress

The SOCKS5 pod nothing ever pointed at is gone, as is qbittorrent's private
sidecar. Apps opt into one shared path with the
[`netbird-egress`](../kubernetes/components/netbird-egress/) component
(qbittorrent, prowlarr, flaresolverr, sonarr, radarr, shelfarr). It stamps
`lab.bwees/netbird: airvpn-egress` - which `SidecarProfile/airvpn-egress` in the
`media` namespace selects - and adds the init container that keeps cluster traffic
off the tunnel.

That init container is the subtle part. NetBird's `ip rule` at **priority 105**
(`suppress_prefixlen 0`) only returns a packet to the main table if a *specific*
route matches there, and a pod's main table holds nothing but a default route. So
without help, the exit node swallows CoreDNS, the API server and the replies to
envoy. The component installs `to 10.42.0.0/16` and `to 10.43.0.0/16` rules at
**priority 100** - it must beat 105. (The old Tailscale init container used 5252,
which would be ignored here.)

qbittorrent keeps `dnsPolicy: None` with `1.1.1.1`: those queries fall outside the
bypassed CIDRs, so tracker DNS resolves through AirVPN.

## The injection webhook is scoped on purpose

Every injected pod carries a `lab.bwees/netbird` label (`ingress`, `dns`, `wolf`,
`airvpn-egress`) and the operator's pod webhook has an `objectSelector` requiring
it. The chart ships the webhook cluster-wide with `failurePolicy: Fail`, which
would make the operator a hard dependency of every pod admission in the cluster -
a full reboot could deadlock on it. Scoped this way, `Fail` keeps only its useful
meaning: a pod that is supposed to be on the mesh never starts silently off it.
The trade-off is that while the operator is down, those pods will not start.

## Manual steps before this reconciles

1. **NetBird account** (cloud, `api.netbird.io`). Create a PAT for the operator.
2. **1Password items** in `Homelab Deployment`:
   - `netbird-operator` → field `credential`: the PAT.
   - `airvpn` → `private_key`, `preshared_key`, `addresses`, `forwarded_port`,
     from AirVPN's config generator (Linux/WireGuard) and the client area.
   - `tofu-credentials` → new `netbird` section, field `token`: an admin PAT.
3. **`tofu apply`** first. The operator's `SetupKey` resources resolve groups *by
   name* and fail until the groups exist.
4. **Log the nodes in**: `tofu output -json node_setup_keys`, then on each host
   `netbird up --setup-key <key>`. The key carries the groups, including the
   exit-node group for eridani and tau-ceti.
5. **Delete the Tailscale tailnet resources** once DNS has moved - the tailnet ACL
   and devices are no longer described anywhere in this repo.

## What to verify, in this order

Test on k3d or stepien before hail-mary; the DNS cutover is the risky part.

1. `kubectl -n networking get pods` - envoy pods have 2 containers.
2. `netbird status` on a laptop resolves `stepien-ingress.netbird.cloud` and an
   HTTPS request to a `*.bwees.dev` name on that cluster still terminates on envoy
   with the wildcard cert.
3. Two envoy replicas → two A records for one label (the HA assumption).
4. `dig @dns.netbird.cloud` from another cluster's external-dns pod, then confirm
   RFC2136 updates still land in bind9.
5. Exit node: `netbird status -d` on the exit-node pod shows a **direct** (not
   relayed) connection, and `curl ifconfig.me` from a media pod returns an AirVPN
   address while `nslookup` of a cluster Service still works.
6. Kill the gluetun container and confirm the media pods lose egress rather than
   falling back to the ISP.

## Open risks

- **Duplicate extra DNS labels across peers** is what the ingress HA rests on. The
  zone builder appends one record per peer, so it should work, but the management
  API may yet validate labels as unique - verify with two replicas before relying
  on it (item 3 above).
- **Injected sidecars are privileged** (`NET_ADMIN`, `SYS_ADMIN`, `privileged:
  true`), which the Tailscale ProxyGroup pods were not - and envoy, bind9 and wolf
  now all run one. This is the biggest posture change in the migration.
- **Peer churn**: every restart of an injected pod burns a peer registration.
  Ephemeral keys clean up after 10 minutes, but a crash-looping pod will produce a
  lot of them, and NetBird Cloud's free tier caps peers.
- **Ordering**: `netbird-peers` must exist before any pod that expects injection.
  A pod that starts first silently gets no client at all, which looks like a
  networking bug rather than an ordering bug. The media `netbird` Kustomization is
  `wait: true` for this reason.
- **The exit node is a single point of failure** and a single pipe. Nothing here is
  HA, and all media egress plus any device in `vpn-clients` shares it.
- **`netbird_nameserver_group` is set primary for all peers** (1.1.1.1), mirroring
  the old tailnet nameservers. Confirm on one cluster that this does not disturb
  the bind9 → CoreDNS → host resolver chain that serves the `bwees.io` split view.
