data "opwan_account" "this" {}

locals {
  dfw_ipv4 = one([for a in data.opwan_account.this.addresses : a.ip if a.location == "dfw"])
}

// The private half is WIREGUARD_PRIVATE_KEY in Infisical's /envoy-dfp, read by hail-mary's envoy-dfp.
resource "opwan_tunnel" "dfw" {
  name       = "DFW Public"
  location   = "dfw"
  public_key = "YSInPZuwo89XfFU7u/EqZe8l0k2plzT4yS86mzKwAmY="
}

// hail-mary's envoy-dfp only serves 80 and 443 on this address; ICMP keeps path MTU discovery working
resource "opwan_firewall" "dfw" {
  ip             = local.dfw_ipv4
  default_action = "deny"

  rules = [
    { action = "allow", protocol = "tcp", ports = "80, 443" },
    { action = "allow", protocol = "icmp" },
  ]
}
