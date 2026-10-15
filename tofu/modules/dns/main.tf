resource "cloudflare_dns_record" "bwees_io_wildcard" {
  zone_id = var.bwees_io_zone_id
  name    = "*"
  type    = "A"
  content = var.public_ingress_ipv4
  comment = "Public ingress on tau-ceti. Managed by Tofu."
  proxied = false
  ttl     = 300
}

resource "cloudflare_dns_record" "bwees_dev_static" {
  for_each = var.bwees_dev_static_records

  zone_id = var.bwees_dev_zone_id
  name    = each.key
  type    = "A"
  content = each.value
  comment = "Static LAN address. Managed by Tofu."
  proxied = false
  ttl     = 300
}
