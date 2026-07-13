provider "onepassword" {}

data "onepassword_item" "cloudflare" {
  vault = "Homelab Deployment"
  title = "tofu-credentials"
}

provider "cloudflare" {
  api_token = data.onepassword_item.cloudflare.section_map["cloudflare"].field_map["api_token"].value
}

provider "tailscale" {
  oauth_client_id     = data.onepassword_item.cloudflare.section_map["tailscale"].field_map["client_id"].value
  oauth_client_secret = data.onepassword_item.cloudflare.section_map["tailscale"].field_map["client_secret"].value
  tailnet             = "tail72746.ts.net"
}

