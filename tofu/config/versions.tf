terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "3.3.1"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.22.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.29.2"
    }
  }
}
