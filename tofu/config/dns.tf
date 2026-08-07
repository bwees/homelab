resource "cloudflare_dns_record" "bwees_io_wildcard" {
  zone_id = data.cloudflare_zone.bwees_io.zone_id
  name    = "*"
  type    = "A"
  content = "45.137.192.163"
  comment = "Public ingress on tau-ceti. Managed by Tofu."
  proxied = false
  ttl     = 300
}
