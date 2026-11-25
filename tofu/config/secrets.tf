// Every folder the clusters read from Infisical. Folders are named after the app that
// consumes them, secret names describe the value, and each ExternalSecret maps them
// onto whatever keys its app expects.
module "infisical_secrets" {
  source = "../modules/infisical-secrets"

  project_id       = module.infisical.project_id
  environment_slug = module.infisical.environment_slug

  folders = [
    "/bind9",
    "/browser",
    "/cah",
    "/envoy-dfp",
    "/gatus",
    "/github-status",
    "/gitea-mirror",
    "/hermes",
    "/magpie",
    "/pinchflat",
    "/readme-stats",
    "/volsync/nas",
    "/zulip-demo",
    "/zulu-notifyd",
  ]

  secrets = merge(
    {
      "/cert-manager" = {
        CLOUDFLARE_API_TOKEN = module.api_tokens.tokens["cert_manager"]
      }
      "/external-dns" = {
        CLOUDFLARE_API_TOKEN = module.api_tokens.tokens["external_dns"]
      }
      "/pages-deployment" = {
        CLOUDFLARE_API_TOKEN = module.api_tokens.tokens["pages_deployment"]
      }
      "/tailscale-operator" = {
        CLIENT_ID     = module.tailscale.operator_client_id
        CLIENT_SECRET = module.tailscale.operator_client_secret
      }
      "/unifi-ddns" = {
        CLOUDFLARE_API_TOKEN = module.api_tokens.tokens["unifi_ddns"]
      }
      "/volsync/b2" = {
        REPOSITORY        = module.restic.repository
        ACCESS_KEY_ID     = module.restic.key_id
        SECRET_ACCESS_KEY = module.restic.application_key
      }
    },
    { for cluster in local.clusters : "/github-webhook/${cluster}" => { WEBHOOK_TOKEN = module.flux_webhooks.tokens[cluster] } },
  )
}
