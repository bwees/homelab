// Hosts that are not fronted by a cluster Gateway, so external-dns never sees
// them. Public records holding LAN addresses: only reachable from that LAN or
// over the tailnet subnet router.
locals {
  bwees_dev_static_records = {
    nas = "192.168.50.4"
    p2s = "192.168.10.66"
  }
}
