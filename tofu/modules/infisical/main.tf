locals {
  project_slug     = "homelab"
  environment_slug = "prod"
}

data "infisical_identity_details" "tofu" {}

resource "infisical_project" "homelab" {
  name                       = "homelab"
  slug                       = local.project_slug
  should_create_default_envs = false
  has_delete_protection      = true
}

resource "infisical_project_environment" "prod" {
  name       = "prod"
  project_id = infisical_project.homelab.id
  slug       = local.environment_slug
}

resource "infisical_identity" "cluster" {
  for_each = var.clusters

  name   = "kubernetes-${each.value}"
  org_id = data.infisical_identity_details.tofu.organization.id
  role   = "no-access"
}

resource "infisical_identity_universal_auth" "cluster" {
  for_each = var.clusters

  identity_id = infisical_identity.cluster[each.value].id
}

resource "infisical_identity_universal_auth_client_secret" "cluster" {
  for_each = var.clusters

  identity_id = infisical_identity_universal_auth.cluster[each.value].identity_id
  description = "external-secrets on ${each.value}"
}

resource "infisical_project_identity" "cluster" {
  for_each = var.clusters

  project_id  = infisical_project.homelab.id
  identity_id = infisical_identity.cluster[each.value].id
  roles       = [{ role_slug = "viewer" }]
}
