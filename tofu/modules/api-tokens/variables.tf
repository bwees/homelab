variable "account_id" {
  type = string
}

variable "cert_manager_zone_ids" {
  type = set(string)
}

variable "external_dns_zone_ids" {
  type = set(string)
}

variable "vault_uuid" {
  type = string
}
