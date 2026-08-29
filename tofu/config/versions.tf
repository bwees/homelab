terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "3.3.1"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.24.0"
    }

    netbird = {
      source  = "netbirdio/netbird"
      version = "0.0.10"
    }
  }
}
