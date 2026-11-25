variable "project_id" {
  type = string
}

variable "environment_slug" {
  type = string
}

variable "folders" {
  description = "Folders whose secrets are entered by hand"
  type        = set(string)
  default     = []
}

variable "secrets" {
  description = "Secrets tofu owns, keyed by folder path, then secret name"
  type        = map(map(string))
  default     = {}

  validation {
    condition     = alltrue([for name in flatten([for secrets in values(var.secrets) : keys(secrets)]) : can(regex("^[A-Z][A-Z0-9_]*$", name))])
    error_message = "Secret names are UPPER_SNAKE_CASE."
  }
}
