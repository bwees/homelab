variable "tunnels" {
  type = set(string)

  default = [
    "eridani",
    "hail-mary",
    "stepien",
    "tau-ceti",
  ]
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnels" {
  for_each = var.tunnels

  account_id = data.cloudflare_account.main.id
  name       = each.key
  config_src = "cloudflare"
}

resource "cloudflare_dns_record" "tunnels" {
  for_each = var.tunnels

  zone_id = data.cloudflare_zone.bwees_io.zone_id
  name    = "${each.key}.tun"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.key].id}.cfargotunnel.com"
  comment = "Cloudflare Tunnel for ${each.key}. Managed by Tofu."
  proxied = true

  ttl = 1
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "tunnels" {
  for_each = var.tunnels

  account_id = data.cloudflare_account.main.id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnels[each.key].id
}

resource "onepassword_item" "tunnel_tokens" {
  for_each = var.tunnels

  vault    = data.onepassword_vault.homelab_deployment.uuid
  title    = "cf-tunnel-${each.key}"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "token" = {
          type  = "CONCEALED"
          value = data.cloudflare_zero_trust_tunnel_cloudflared_token.tunnels[each.key].token
        }
      }
    }
  }
}

