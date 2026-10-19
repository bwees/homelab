resource "cloudflare_account_token" "cert_manager" {
  account_id = var.account_id
  name       = "k3s cert-manager DNS01"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
        { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
      ]
      resources = jsonencode({
        for zone_id in var.cert_manager_zone_ids : "com.cloudflare.api.account.zone.${zone_id}" => "*"
      })
    }
  ]
}

resource "onepassword_item" "cf_cert_manager" {
  vault    = var.vault_uuid
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

resource "cloudflare_account_token" "external_dns" {
  account_id = var.account_id
  name       = "k3s external-dns"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
        { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
      ]
      resources = jsonencode({
        for zone_id in var.external_dns_zone_ids : "com.cloudflare.api.account.zone.${zone_id}" => "*"
      })
    }
  ]
}

resource "onepassword_item" "cf_external_dns" {
  vault    = var.vault_uuid
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
  account_id = var.account_id
  name       = "Pages Deployment"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "8d28297797f24fb8a0c332fe0866ec89" }, # Pages Edit
      ]
      resources = jsonencode({
        "com.cloudflare.api.account.${var.account_id}" = "*"
      })
    }
  ]
}

resource "onepassword_item" "cf_pages_deployment" {
  vault    = var.vault_uuid
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

resource "cloudflare_account_token" "unifi_ddns" {
  account_id = var.account_id
  name       = "UniFi DDNS"

  policies = [
    {
      effect = "allow"
      permission_groups = [
        { id = "4755a26eedb94da69e1066d98aa820be" }, # DNS Write
        { id = "c8fed203ed3043cba015a93ad1616f1f" }, # Zone Read
      ]
      resources = jsonencode({
        for zone_id in var.external_dns_zone_ids : "com.cloudflare.api.account.zone.${zone_id}" => "*"
      })
    }
  ]
}

resource "onepassword_item" "unifi_ddns" {
  vault    = var.vault_uuid
  title    = "unifi-ddns"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "token" = {
          type  = "CONCEALED"
          value = cloudflare_account_token.unifi_ddns.value
        }
      }
    }
  }
}