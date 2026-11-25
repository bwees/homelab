output "operator_client_id" {
  value = tailscale_oauth_client.operator.id
}

output "operator_client_secret" {
  value     = tailscale_oauth_client.operator.key
  sensitive = true
}
