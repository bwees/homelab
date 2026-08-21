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
  tailnet  = "tail72746.ts.net"
  clusters = ["tau-ceti", "hail-mary", "stepien", "eridani"]
}