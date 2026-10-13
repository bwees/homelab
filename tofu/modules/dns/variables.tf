variable "bwees_io_zone_id" {
  type = string
}

variable "bwees_dev_zone_id" {
  type = string
}

variable "maroonrides_app_zone_id" {
  type = string
}

variable "public_ingress_ipv4" {
  type = string
}

variable "bwees_dev_static_records" {
  description = "Hostname to LAN address"
  type        = map(string)
  default     = {}
}
