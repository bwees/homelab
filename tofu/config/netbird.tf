# Groups are the only handle the rest of the stack has on NetBird: the operator's
# SetupKey resources reference them by name and refuse to reconcile until they
# exist, so they are created here rather than in-cluster.
resource "netbird_group" "cluster" {
  for_each = toset(local.clusters)

  name = each.value
}

resource "netbird_group" "k8s_ingress" {
  name = "k8s-ingress"
}

resource "netbird_group" "k8s_service" {
  name = "k8s-service"
}

resource "netbird_group" "nixos" {
  name = "nixos"
}

# Holds the one peer that carries the 0.0.0.0/0 route.
resource "netbird_group" "exit_node_airvpn" {
  name = "exit-node-airvpn"
}

# Peers whose internet traffic should leave through AirVPN. The media stack's
# setup key auto-assigns this; adding a laptop or phone is a group membership
# change in the dashboard, not a config change here.
resource "netbird_group" "vpn_clients" {
  name = "vpn-clients"
}

# Home LAN and public-VPS exit nodes, kept out of the auto-applied path so a
# client only takes them when it asks for them (see skip_auto_apply below).
resource "netbird_group" "exit_node_home" {
  name = "exit-node-home"
}

resource "netbird_group" "exit_node_vps" {
  name = "exit-node-vps"
}

data "netbird_group" "all" {
  name = "All"
}

# Same posture as the Tailscale ACL this replaces: one flat accept. Route traffic
# is matched by the route's own access control groups, not by this policy.
resource "netbird_policy" "default" {
  name    = "default-allow"
  enabled = true

  rule {
    name          = "allow-all"
    action        = "accept"
    protocol      = "all"
    bidirectional = true
    enabled       = true
    sources       = [data.netbird_group.all.id]
    destinations  = [data.netbird_group.all.id]
  }
}

# The exit node itself: a gluetun+NetBird pod on hail-mary whose default route is
# an AirVPN WireGuard tunnel. masquerade is what makes the AirVPN egress address
# the source address seen by the internet.
resource "netbird_route" "airvpn_exit" {
  network_id  = "airvpn"
  description = "AirVPN exit node (hail-mary)"
  network     = "0.0.0.0/0"
  peer_groups = [netbird_group.exit_node_airvpn.id]
  groups      = [netbird_group.vpn_clients.id]
  masquerade  = true
  enabled     = true
}

# Replaces `--advertise-routes=10.0.1.0/24` on eridani: the LAN behind the home
# node, reachable from every peer.
resource "netbird_route" "eridani_lan" {
  network_id  = "eridani-lan"
  description = "eridani LAN"
  network     = "10.0.1.0/24"
  peer_groups = [netbird_group.exit_node_home.id]
  groups      = [data.netbird_group.all.id]
  masquerade  = true
  enabled     = true
}

# Replaces `--advertise-exit-node` on the NixOS hosts. skip_auto_apply keeps these
# off every peer's default route - a client selects one explicitly, the way it
# picked a Tailscale exit node.
resource "netbird_route" "home_exit" {
  network_id      = "exit-home"
  description     = "eridani exit node"
  network         = "0.0.0.0/0"
  peer_groups     = [netbird_group.exit_node_home.id]
  groups          = [data.netbird_group.all.id]
  masquerade      = true
  enabled         = true
  skip_auto_apply = true
}

resource "netbird_route" "vps_exit" {
  network_id      = "exit-vps"
  description     = "tau-ceti exit node"
  network         = "0.0.0.0/0"
  peer_groups     = [netbird_group.exit_node_vps.id]
  groups          = [data.netbird_group.all.id]
  masquerade      = true
  enabled         = true
  skip_auto_apply = true
}

# One reusable key per cluster for the NixOS nodes, which log in by hand
# (`netbird up --setup-key ...`) exactly as they ran `tailscale up`. The
# in-cluster keys are owned by the operator's SetupKey resources instead.
resource "netbird_setup_key" "node" {
  for_each = toset(local.clusters)

  name           = "${each.value}-nodes"
  type           = "reusable"
  expiry_seconds = 0
  ephemeral      = false
  auto_groups = concat(
    [netbird_group.nixos.id, netbird_group.cluster[each.value].id],
    lookup(local.node_exit_groups, each.value, []),
  )
}

output "node_setup_keys" {
  description = "Per-cluster NixOS setup keys; `tofu output -json node_setup_keys`."
  sensitive   = true
  value       = { for cluster, key in netbird_setup_key.node : cluster => key.key }
}

# Mirrors the Tailscale nameserver config: peers resolve public names through
# Cloudflare rather than whatever network they are on.
resource "netbird_nameserver_group" "cloudflare" {
  name        = "cloudflare"
  description = "Public resolver for all peers"
  enabled     = true
  primary     = true
  groups      = [data.netbird_group.all.id]

  nameservers = [
    { ip = "1.1.1.1", ns_type = "udp", port = 53 },
    { ip = "1.0.0.1", ns_type = "udp", port = 53 },
  ]
}

resource "netbird_account_settings" "main" {
  # Every peer here joins with a setup key, so interactive login expiry would only
  # ever strand a machine.
  peer_login_expiration_enabled       = false
  peer_inactivity_expiration_enabled  = false
  routing_peer_dns_resolution_enabled = true
  groups_propagation_enabled          = true
}
