# hail-mary

Multi-node HA k3s cluster. Every node runs k3s with `role = "server"` (control-plane +
embedded etcd), so each host is a full member of the etcd quorum. Shared k3s configuration
lives in [`../../lib/k3s.nix`](../../lib/k3s.nix) and [`../../lib/k3s-multinode.nix`](../../lib/k3s-multinode.nix).

## Nodes

| Node       | LAN IP           | Role                                    |
| ---------- | ---------------- | --------------------------------------- |
| grace      | `192.168.50.110` | Cluster init (bootstraps etcd), storage |
| rocky      | `192.168.50.111` | Server, storage                         |
| xenonite   | `192.168.50.106` | Server, storage                         |
| astrophage | `192.168.50.4`   | Server, quorum-only (unschedulable)     |

`grace` is the only node with `services.k3s.clusterInit = true`. Every other node joins it
with `services.k3s.serverAddr = "https://192.168.50.110:6443"`.

## Joining a new node

A node needs two things to join: the NixOS config pointing it at grace, and the shared
cluster token. The token is a secret and is **not** in the repo — it lives at
`/etc/rancher/k3s/cluster-token` on each node and must be copied out of band.

1. **Provision the machine.** Add the host directory and wire it into
   [`../../flake.nix`](../../flake.nix), then provision from scratch:

   ```bash
   mise run nixos:anywhere <host> <ip>
   ```

2. **Configure it as a joining server**, not a new cluster. The host's
   `configuration.nix` must use `serverAddr` (copy an existing node like `rocky`), *not*
   `clusterInit`:

   ```nix
   services.k3s.serverAddr = "https://192.168.50.110:6443";
   services.k3s.tokenFile = "/etc/rancher/k3s/cluster-token";
   ```

   > Copying `grace`'s config verbatim is a trap: `clusterInit = true` makes the node
   > bootstrap its own separate cluster instead of joining hail-mary.

3. **Apply the config:**

   ```bash
   mise run nixos:switch <host>
   ```

   k3s will fail to start and log `Waiting for file "/etc/rancher/k3s/cluster-token"` —
   expected, the token isn't there yet.

4. **Seed the cluster token** from an existing node. This pipes host-to-host so the secret
   never touches local disk:

   ```bash
   ssh <user>@grace 'sudo cat /etc/rancher/k3s/cluster-token' \
     | ssh <user>@<host> 'sudo mkdir -p /etc/rancher/k3s \
         && sudo install -m 0600 -o root -g root /dev/stdin /etc/rancher/k3s/cluster-token'
   ```

5. **Restart k3s and confirm the node joins:**

   ```bash
   ssh <user>@<host> 'sudo systemctl restart k3s'
   ssh <user>@grace 'sudo k3s kubectl get nodes'
   ```

   The node should reach `Ready` within a few seconds and show up as an etcd member.

## Longhorn default disk

Nodes providing storage carry `--node-label=node.longhorn.io/create-default-disk=true`
(see the host `configuration.nix`) and a dedicated `@longhorn` btrfs subvolume mounted at
`/var/lib/longhorn`. With `create-default-disk-labeled-nodes=true` set in Longhorn, a
default disk on that path is created automatically.

There is a race on a fresh join: if longhorn-manager creates the Longhorn `Node` resource
before k3s's registration label is visible, no default disk is created and the node has no
storage. If `spec.disks` is empty after the node is `Ready`, re-apply the label to trigger
creation:

```bash
sudo k3s kubectl label node <host> node.longhorn.io/create-default-disk=true --overwrite
sudo k3s kubectl get nodes.longhorn.io -n storage <host> \
  -o jsonpath='{.spec.disks}'   # should no longer be {}
```
