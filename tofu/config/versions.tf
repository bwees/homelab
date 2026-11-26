terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.29.0"
    }

    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.30.0"
    }

    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }

    b2 = {
      source  = "Backblaze/b2"
      version = "0.14.1"
    }

    opwan = {
      source  = "registry.terraform.io/slop-place/opwan"
      version = "0.2.0"
    }

    infisical = {
      source  = "Infisical/infisical"
      version = "0.20.23"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}
