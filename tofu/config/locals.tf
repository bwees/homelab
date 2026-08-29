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
  name = "Homelab Deployment"
}

locals {
  clusters = ["tau-ceti", "hail-mary", "stepien", "eridani"]

  # Clusters whose node also serves an exit node (and, for eridani, the LAN route).
  node_exit_groups = {
    "eridani"  = [netbird_group.exit_node_home.id]
    "tau-ceti" = [netbird_group.exit_node_vps.id]
  }
}