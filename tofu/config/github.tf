// notification-controller hashes the shared secret together with the Receiver's
// name and namespace to build the path it answers on, so the hook URL is
// reproducible here without reading anything back out of the clusters. The
// Receiver lives at kubernetes/apps/base/flux-system/github-webhook.
locals {
  flux_webhook_paths = {
    for cluster, token in random_password.flux_webhook :
    cluster => "/hook/${sha256("${token.result}github-receiverflux-system")}"
  }
}

resource "random_password" "flux_webhook" {
  for_each = toset(local.clusters)

  length  = 40
  special = false
}

resource "onepassword_item" "flux_webhooks" {
  vault    = data.onepassword_vault.homelab_deployment.uuid
  title    = "flux-webhooks"
  category = "password"

  section_map = {
    "credentials" = {
      field_map = {
        for cluster, token in random_password.flux_webhook : cluster => {
          type  = "CONCEALED"
          value = token.result
        }
      }
    }
  }
}

resource "github_repository_webhook" "flux" {
  for_each = toset(local.clusters)

  repository = "homelab"
  events     = ["push"]

  configuration {
    url          = "https://fluxhook-${each.key}.bwees.io${local.flux_webhook_paths[each.key]}"
    content_type = "json"
    secret       = random_password.flux_webhook[each.key].result
  }
}
