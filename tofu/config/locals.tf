data "cloudflare_account" "main" {
  account_id = "5e2ba2ec4aedeea294c2bf45f28c6414"
}

data "cloudflare_zone" "bwees_io" {
  zone_id = "72e8e948ac04faef676a0a877bab6f9d"
}

data "cloudflare_zone" "bwees_dev" {
  zone_id = "16abc0a51d3df8322d69e9b3a5928776"
}

data "onepassword_vault" "homelab_deployment" {
  name = local.vault_name
}

locals {
  vault_name   = "Homelab Deployment"
  github_owner = "bwees"
  admin        = "brandonwees@gmail.com"
  tailnet      = "tail72746.ts.net"
  clusters     = ["tau-ceti", "hail-mary", "stepien", "eridani"]

  mullvad_nodes = [
    "brandon-iphone-17",
    "brandon-ipad-air",
    "brandon-macbook-pro",
    "qbittorrent",
  ]

  account_id = data.cloudflare_account.main.account_id
  vault_uuid = data.onepassword_vault.homelab_deployment.uuid
}
