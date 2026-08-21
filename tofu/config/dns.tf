resource "cloudflare_dns_record" "bwees_io_wildcard" {
  zone_id = data.cloudflare_zone.bwees_io.zone_id
  name    = "*"
  type    = "A"
  content = "45.137.192.163"
  comment = "Public ingress on tau-ceti. Managed by Tofu."
  proxied = false
  ttl     = 300
}

// Hosts that are not fronted by a cluster Gateway, so external-dns never sees
// them. Public records holding LAN addresses: only reachable from that LAN or
// over the tailnet subnet router.
locals {
  bwees_dev_static_records = {
    nas = "192.168.50.4"
    p2s = "192.168.10.66"
  }
}

resource "cloudflare_dns_record" "bwees_dev_static" {
  for_each = local.bwees_dev_static_records

  zone_id = data.cloudflare_zone.bwees_dev.zone_id
  name    = each.key
  type    = "A"
  content = each.value
  comment = "Static LAN address. Managed by Tofu."
  proxied = false
  ttl     = 300
}
