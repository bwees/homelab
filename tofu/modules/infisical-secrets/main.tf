locals {
  paths   = setunion(var.folders, toset(keys(var.secrets)))
  parents = toset([for path in local.paths : dirname(path) if dirname(path) != "/"])

  top_level = setunion(local.parents, toset([for path in local.paths : path if dirname(path) == "/"]))
  nested    = toset([for path in local.paths : path if dirname(path) != "/"])

  secrets = merge([
    for path, secrets in var.secrets : {
      for name, value in secrets : "${path}/${name}" => { path = path, name = name, value = value }
    }
  ]...)

  folder_path_pattern = "^(/[a-z0-9-]+){1,2}$"
}

resource "infisical_secret_folder" "top_level" {
  for_each = local.top_level

  project_id       = var.project_id
  environment_slug = var.environment_slug
  folder_path      = "/"
  name             = basename(each.value)

  lifecycle {
    precondition {
      condition     = can(regex(local.folder_path_pattern, each.value))
      error_message = "Folder paths are one or two kebab-case levels deep, e.g. /hermes or /github-webhook/hail-mary."
    }
  }
}

resource "infisical_secret_folder" "nested" {
  for_each = local.nested

  project_id       = var.project_id
  environment_slug = var.environment_slug
  folder_path      = dirname(each.value)
  name             = basename(each.value)

  lifecycle {
    precondition {
      condition     = can(regex(local.folder_path_pattern, each.value))
      error_message = "Folder paths are one or two kebab-case levels deep, e.g. /hermes or /github-webhook/hail-mary."
    }
  }

  depends_on = [infisical_secret_folder.top_level]
}

resource "infisical_secret" "this" {
  for_each = local.secrets

  workspace_id = var.project_id
  env_slug     = var.environment_slug
  folder_path  = each.value.path
  name         = each.value.name
  value        = each.value.value

  depends_on = [infisical_secret_folder.top_level, infisical_secret_folder.nested]
}
