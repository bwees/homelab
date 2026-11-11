locals {
  permission_groups = {
    dns_write  = "4755a26eedb94da69e1066d98aa820be"
    zone_read  = "c8fed203ed3043cba015a93ad1616f1f"
    pages_edit = "8d28297797f24fb8a0c332fe0866ec89"
  }

  dns_permission_groups = [
    local.permission_groups.dns_write,
    local.permission_groups.zone_read,
  ]

  tokens = {
    cert_manager = {
      name              = "k3s cert-manager DNS01"
      item_title        = "cf-cert-manager"
      permission_groups = local.dns_permission_groups
      resources         = { for zone_id in var.cert_manager_zone_ids : "com.cloudflare.api.account.zone.${zone_id}" => "*" }
    }
    external_dns = {
      name              = "k3s external-dns"
      item_title        = "cf-external-dns"
      permission_groups = local.dns_permission_groups
      resources         = { for zone_id in var.external_dns_zone_ids : "com.cloudflare.api.account.zone.${zone_id}" => "*" }
    }
    pages_deployment = {
      name              = "Pages Deployment"
      item_title        = "cf-pages-deployment"
      permission_groups = [local.permission_groups.pages_edit]
      resources         = { "com.cloudflare.api.account.${var.account_id}" = "*" }
    }
    unifi_ddns = {
      name              = "UniFi DDNS"
      item_title        = "unifi-ddns"
      permission_groups = local.dns_permission_groups
      resources         = { for zone_id in var.unifi_ddns_zone_ids : "com.cloudflare.api.account.zone.${zone_id}" => "*" }
    }
  }
}

resource "cloudflare_account_token" "this" {
  for_each = local.tokens

  account_id = var.account_id
  name       = each.value.name

  policies = [
    {
      effect            = "allow"
      permission_groups = [for id in each.value.permission_groups : { id = id }]
      resources         = jsonencode(each.value.resources)
    }
  ]
}

resource "onepassword_item" "this" {
  for_each = local.tokens

  vault    = var.vault_uuid
  title    = each.value.item_title
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        "token" = {
          type  = "CONCEALED"
          value = cloudflare_account_token.this[each.key].value
        }
      }
    }
  }
}
