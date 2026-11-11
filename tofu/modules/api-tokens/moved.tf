moved {
  from = cloudflare_account_token.cert_manager
  to   = cloudflare_account_token.this["cert_manager"]
}

moved {
  from = cloudflare_account_token.external_dns
  to   = cloudflare_account_token.this["external_dns"]
}

moved {
  from = cloudflare_account_token.pages_deployment
  to   = cloudflare_account_token.this["pages_deployment"]
}

moved {
  from = cloudflare_account_token.unifi_ddns
  to   = cloudflare_account_token.this["unifi_ddns"]
}

moved {
  from = onepassword_item.cf_cert_manager
  to   = onepassword_item.this["cert_manager"]
}

moved {
  from = onepassword_item.cf_external_dns
  to   = onepassword_item.this["external_dns"]
}

moved {
  from = onepassword_item.cf_pages_deployment
  to   = onepassword_item.this["pages_deployment"]
}

moved {
  from = onepassword_item.unifi_ddns
  to   = onepassword_item.this["unifi_ddns"]
}
