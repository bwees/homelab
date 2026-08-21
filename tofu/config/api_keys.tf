// cert-manager DNS-01 for the bwees.io and bwees.dev wildcards. Zone Read is
// required alongside DNS Write so it can look the zone up before writing the
// challenge.
resource "cloudflare_account_token" "cert_manager" {
  account_id = data.cloudflare_account.main.id
  name       = "k3s cert-manager DNS01"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
        { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${data.cloudflare_zone.bwees_io.zone_id}"  = "*"
        "com.cloudflare.api.account.zone.${data.cloudflare_zone.bwees_dev.zone_id}" = "*"
      })
    }
  ]
}

resource "onepassword_item" "cf_cert_manager" {
  vault    = data.onepassword_vault.homelab_deployment.uuid
  title    = "cf-cert-manager"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "token" = {
          type  = "CONCEALED"
          value = cloudflare_account_token.cert_manager.value
        }
      }
    }
  }
}

// Kubernetes external-dns publishes every internal record into bwees.dev. Scoped
// to that zone alone so it can never touch the public bwees.io wildcard.
resource "cloudflare_account_token" "external_dns" {
  account_id = data.cloudflare_account.main.id
  name       = "k3s external-dns"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
        { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.zone.${data.cloudflare_zone.bwees_dev.zone_id}" = "*"
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
        "token" = {
          type  = "CONCEALED"
          value = cloudflare_account_token.external_dns.value
        }
      }
    }
  }
}

resource "cloudflare_account_token" "pages_deployment" {
  account_id = data.cloudflare_account.main.id
  name       = "Pages Deployment"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "8d28297797f24fb8a0c332fe0866ec89" }, # Pages Edit
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.${data.cloudflare_account.main.id}" = "*"
      })
    }
  ]
}

resource "onepassword_item" "cf_pages_deployment" {
  vault    = data.onepassword_vault.homelab_deployment.uuid
  title    = "cf-pages-deployment"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "token" = {
          type  = "CONCEALED"
          value = cloudflare_account_token.pages_deployment.value
        }
      }
    }
  }
}
