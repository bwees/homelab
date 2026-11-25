# Tofu

Used to manage third-party services with IaC.

## Credentials

Only these come from the environment (`tofu/.env` locally, repository secrets in CI):

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: Cloudflare R2 token with read and write access to the `homelab-tofu-state` bucket
- `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID` / `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET`: Infisical machine identity with the org Admin role, also a member of the `opentofu` project

Every provider credential is read from the root of the Infisical `opentofu` project, `prod` environment:

- `CLOUDFLARE_API_TOKEN`: Cloudflare API token
  - Brandon Wees: API Tokens:Edit, Account Settings:Read
  - bwees.io: Zone:Read, DNS:Edit
  - bwees.dev: Zone:Read, DNS:Edit
- `GITHUB_TOKEN`: GitHub token with admin access to repository webhooks on `bwees/homelab`
- `B2_APPLICATION_KEY_ID` / `B2_APPLICATION_KEY`: Backblaze B2 application key for all buckets, with `writeKeys` and `writeBuckets`
- `OPWAN_API_KEY`: opwan API key
- `TAILSCALE_OAUTH_CLIENT_ID` / `TAILSCALE_OAUTH_CLIENT_SECRET`: Tailscale OAuth client with all scopes

The `opentofu` project is created by hand and kept apart from `homelab`, so cluster identities cannot read these.
