output "tokens" {
  value     = { for name, token in cloudflare_account_token.this : name => token.value }
  sensitive = true
}
