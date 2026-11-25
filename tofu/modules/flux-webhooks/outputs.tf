output "tokens" {
  value     = { for cluster, token in random_password.flux_webhook : cluster => token.result }
  sensitive = true
}
