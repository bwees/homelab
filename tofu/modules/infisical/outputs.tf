output "project_id" {
  value = infisical_project.homelab.id
}

output "environment_slug" {
  value = infisical_project_environment.prod.slug
}

output "cluster_credentials" {
  value = {
    for cluster, secret in infisical_identity_universal_auth_client_secret.cluster : cluster => {
      client_id     = secret.client_id
      client_secret = secret.client_secret
    }
  }
  sensitive = true
}
