resource "cloudflare_dns_record" "bwees_io_wildcard" {
  zone_id = data.cloudflare_zone.bwees_io.zone_id
  name    = "*"
  type    = "CNAME"
  content = cloudflare_dns_record.tunnels["tau-ceti"].name
  comment = "Managed by Tofu."
  proxied = true
  ttl     = 1
}
