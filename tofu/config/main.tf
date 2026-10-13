module "contabo" {
  source = "../modules/contabo"
}

module "dns" {
  source = "../modules/dns"

  bwees_io_zone_id         = data.cloudflare_zone.bwees_io.zone_id
  bwees_dev_zone_id        = data.cloudflare_zone.bwees_dev.zone_id
  maroonrides_app_zone_id  = data.cloudflare_zone.maroonrides_app.zone_id
  public_ingress_ipv4      = module.contabo.public_ipv4
  bwees_dev_static_records = local.bwees_dev_static_records
}

module "api_tokens" {
  source = "../modules/api-tokens"

  account_id = local.account_id
  vault_uuid = local.vault_uuid

  cert_manager_zone_ids = [
    data.cloudflare_zone.bwees_io.zone_id,
    data.cloudflare_zone.bwees_dev.zone_id,
    data.cloudflare_zone.maroonrides_app.zone_id,
  ]

  external_dns_zone_ids = [
    data.cloudflare_zone.bwees_dev.zone_id,
    data.cloudflare_zone.maroonrides_app.zone_id,
  ]
}

module "restic" {
  source = "../modules/restic"

  bucket_name = "bwees-restic"
  vault_uuid  = local.vault_uuid
}

module "tailscale" {
  source = "../modules/tailscale"

  clusters      = toset(local.clusters)
  admin         = local.admin
  tailnet       = local.tailnet
  mullvad_nodes = toset(local.mullvad_nodes)
  vault_uuid    = local.vault_uuid
}

module "flux_webhooks" {
  source = "../modules/flux-webhooks"

  clusters   = toset(local.clusters)
  repository = "homelab"
  domain     = "bwees.io"
  vault_uuid = local.vault_uuid
}
