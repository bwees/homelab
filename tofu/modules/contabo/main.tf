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

module "nixos" {
  source = "../nixos-host"

  hostname    = "tau-ceti"
  target_host = contabo_instance.tau_ceti.ip_config[0].v4[0].ip
  instance_id = contabo_instance.tau_ceti.id
}
