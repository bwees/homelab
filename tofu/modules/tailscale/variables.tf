variable "clusters" {
  type = set(string)
}

variable "admin" {
  type = string
}

variable "tailnet" {
  type = string
}

variable "mullvad_nodes" {
  description = "Device hostnames on the tailnet that get Mullvad exit nodes"
  type        = set(string)
  default     = []
}

variable "vault_uuid" {
  type = string
}
