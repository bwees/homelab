import {
  to = contabo_instance.tau_ceti
  id = "203199646"
}

resource "contabo_instance" "tau_ceti" {
  display_name = "tau-ceti"

  lifecycle {
    // Destroying cancels the Contabo contract.
    prevent_destroy = true

    // Changing any of these reinstalls the OS.
    ignore_changes = [
      image_id,
      ssh_keys,
      user_data,
      root_password,
      default_user,
    ]
  }
}

locals {
  tau_ceti_public_ipv4 = contabo_instance.tau_ceti.ip_config[0].v4[0].ip
}
