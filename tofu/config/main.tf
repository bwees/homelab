module "opwan" {
  source = "../modules/opwan"
}

module "dns" {
  source = "../modules/dns"

  bwees_io_zone_id         = data.cloudflare_zone.bwees_io.zone_id
  bwees_dev_zone_id        = data.cloudflare_zone.bwees_dev.zone_id
  public_ingress_ipv4      = module.opwan.dfw_ipv4
  bwees_dev_static_records = local.bwees_dev_static_records
}

module "api_tokens" {
  source = "../modules/api-tokens"

  account_id = local.account_id

  cert_manager_zone_ids = [
    data.cloudflare_zone.bwees_io.zone_id,
    data.cloudflare_zone.bwees_dev.zone_id,
  ]

  external_dns_zone_ids = [
    data.cloudflare_zone.bwees_dev.zone_id,
  ]

  unifi_ddns_zone_ids = [
    data.cloudflare_zone.bwees_dev.zone_id,
  ]
}

module "restic" {
  source = "../modules/restic"

  bucket_name = "bwees-restic"
}

module "tailscale" {
  source = "../modules/tailscale"

  clusters      = toset(local.clusters)
  admin         = local.admin
  tailnet       = local.tailnet
  mullvad_nodes = toset(local.mullvad_nodes)
}

module "flux_webhooks" {
  source = "../modules/flux-webhooks"

  clusters   = toset(local.clusters)
  repository = "homelab"
  domain     = "bwees.io"
}

module "infisical" {
  source = "../modules/infisical"

  clusters = toset(local.clusters)
}
