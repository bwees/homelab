
locals {
  cloudflare_account_id = "5e2ba2ec4aedeea294c2bf45f28c6414"
  bwees_io_zone         = "72e8e948ac04faef676a0a877bab6f9d"
}

data "onepassword_vault" "homelab_deployment" {
  name = "Homelab Deployment"
}