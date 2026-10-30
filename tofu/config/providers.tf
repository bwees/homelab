provider "onepassword" {}

data "onepassword_item" "credentials" {
  vault = local.vault_name
  title = "tofu-credentials"
}

locals {
  credentials = data.onepassword_item.credentials.section_map
}

provider "cloudflare" {
  api_token = local.credentials["cloudflare"].field_map["api_token"].value
}

provider "github" {
  owner = local.github_owner
  token = local.credentials["github"].field_map["token"].value
}

provider "contabo" {
  oauth2_client_id     = local.credentials["contabo"].field_map["client_id"].value
  oauth2_client_secret = local.credentials["contabo"].field_map["client_secret"].value
  oauth2_user          = local.credentials["contabo"].field_map["user"].value
  oauth2_pass          = local.credentials["contabo"].field_map["password"].value
}

provider "b2" {
  application_key_id = local.credentials["backblaze"].field_map["key_id"].value
  application_key    = local.credentials["backblaze"].field_map["application_key"].value
}

provider "opwan" {
  api_token = local.credentials["opwan"].field_map["api_key"].value
}

provider "tailscale" {
  oauth_client_id     = local.credentials["tailscale"].field_map["client_id"].value
  oauth_client_secret = local.credentials["tailscale"].field_map["client_secret"].value
  tailnet             = local.tailnet
}
