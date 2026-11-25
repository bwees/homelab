provider "infisical" {}

data "infisical_projects" "tofu" {
  slug = "opentofu"
}

data "infisical_secrets" "credentials" {
  workspace_id = data.infisical_projects.tofu.id
  env_slug     = "prod"
  folder_path  = "/"
}

locals {
  credentials = data.infisical_secrets.credentials.secrets
}

provider "cloudflare" {
  api_token = local.credentials["CLOUDFLARE_API_TOKEN"].value
}

provider "github" {
  owner = local.github_owner
  token = local.credentials["GITHUB_TOKEN"].value
}

provider "b2" {
  application_key_id = local.credentials["B2_APPLICATION_KEY_ID"].value
  application_key    = local.credentials["B2_APPLICATION_KEY"].value
}

provider "opwan" {
  api_token = local.credentials["OPWAN_API_KEY"].value
}

provider "tailscale" {
  oauth_client_id     = local.credentials["TAILSCALE_OAUTH_CLIENT_ID"].value
  oauth_client_secret = local.credentials["TAILSCALE_OAUTH_CLIENT_SECRET"].value
  tailnet             = local.tailnet
}
