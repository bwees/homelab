data "opwan_account" "this" {}

locals {
  dfw_ipv4 = one([for a in data.opwan_account.this.addresses : a.ip if a.location == "dfw"])
}

// The key pair predates this config; hail-mary's envoy-dfp reads the private half from the same item.
data "onepassword_item" "dfw_wireguard" {
  vault = var.vault_uuid
  title = "opwan-dfw"
}

resource "opwan_tunnel" "dfw" {
  location   = "dfw"
  public_key = data.onepassword_item.dfw_wireguard.section_map["wireguard"].field_map["public_key"].value
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
