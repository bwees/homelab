terraform {
  required_providers {
    onepassword = {
      source  = "1Password/onepassword"
      version = "3.3.1"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.27.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.29.2"
    }

    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }

    contabo = {
      source  = "contabo/contabo"
      version = "0.1.44"
    }

    b2 = {
      source  = "Backblaze/b2"
      version = "0.14.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}
