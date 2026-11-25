resource "b2_bucket" "restic" {
  bucket_name = var.bucket_name
  bucket_type = "allPrivate"

  default_server_side_encryption {
    algorithm = "AES256"
    mode      = "SSE-B2"
  }

  // restic prunes by hiding files; without this B2 keeps every old version.
  lifecycle_rules {
    file_name_prefix             = ""
    days_from_hiding_to_deleting = 1
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "b2_account_info" "main" {}

resource "b2_application_key" "restic" {
  key_name   = "restic"
  bucket_ids = [b2_bucket.restic.bucket_id]

  capabilities = [
    "listBuckets",
    "readBuckets",
    "listFiles",
    "readFiles",
    "writeFiles",
    "deleteFiles",
  ]
}
