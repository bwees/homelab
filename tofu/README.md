# Tofu

Used to manage third-party services with IaC.

## Required Credentials

- Cloudflare API Key
  - Permissions
    - Brandon Wees - API Tokens:Edit, Cloudflare Tunnel:Edit, Account Settings:Read
    - bwees.io - Zone:Read, DNS:Edit

- Cloudflare API Token
  - Permissions
    - Read and write access to the `tofu` bucket for state

- 1Password Service Account
  - Permissions
    - Read and write access to the "Homelab Deployment" vault

- Tailscale OAuth Client
  - Permissions: all