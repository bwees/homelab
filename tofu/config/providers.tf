provider "onepassword" {}

data "onepassword_item" "cloudflare" {
  vault = "Homelab Deployment"
  title = "tofu-credentials"
}

provider "cloudflare" {
  api_token = data.onepassword_item.cloudflare.section_map["cloudflare"].field_map["api_token"].value
}

provider "netbird" {
  token = data.onepassword_item.cloudflare.section_map["netbird"].field_map["token"].value
}

