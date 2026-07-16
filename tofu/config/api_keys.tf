
resource "cloudflare_account_token" "external_dns" {
  account_id = data.cloudflare_account.main.id
  name       = "k3s External DNS"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${data.cloudflare_zone.bwees_io.zone_id}" = "*"
      })
    }
  ]
}

resource "onepassword_item" "cf_external_dns" {
  vault    = data.onepassword_vault.homelab_deployment.uuid
  title    = "cf-external-dns"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "zone" = {
          type  = "STRING"
          value = data.cloudflare_zone.bwees_io.zone_id
        }
        "token" = {
          type  = "CONCEALED"
          value = cloudflare_account_token.external_dns.value
        }
      }
    }
  }
}
