output "public_ipv4" {
  value = contabo_instance.tau_ceti.ip_config[0].v4[0].ip
}
