module "install" {
  source = "github.com/nix-community/nixos-anywhere//terraform/install?ref=1.13.0"

  flake       = "${abspath("${path.module}/../../../nixos")}#${var.hostname}"
  target_host = var.target_host

  // Only a new instance id reinstalls; `tofu apply -replace` forces it.
  instance_id = var.instance_id
}
