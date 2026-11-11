# Tofu

Used to manage third-party services with IaC.

## Credentials

Only these come from the environment (`tofu/.env` locally, repository secrets in CI):

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: Cloudflare R2 token with read and write access to the `homelab-tofu-state` bucket
- `OP_SERVICE_ACCOUNT_TOKEN`: 1Password service account with read and write access to the "Homelab Deployment" vault

Every provider credential is read from the `tofu-credentials` item in that vault, one section per provider:

- `cloudflare.api_token`: Cloudflare API token
  - Brandon Wees: API Tokens:Edit, Account Settings:Read
  - bwees.io: Zone:Read, DNS:Edit
  - bwees.dev: Zone:Read, DNS:Edit
- `github.token`: GitHub token with admin access to repository webhooks on `bwees/homelab`
- `backblaze.key_id` / `backblaze.application_key`: Backblaze B2 application key for all buckets, with `writeKeys` and `writeBuckets`
- `opwan.api_key`: opwan API key
- `tailscale.client_id` / `tailscale.client_secret`: Tailscale OAuth client with all scopes
