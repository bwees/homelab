output "key_id" {
  value = b2_application_key.restic.application_key_id
}

output "application_key" {
  value     = b2_application_key.restic.application_key
  sensitive = true
}

output "repository" {
  value = "s3:${trimprefix(data.b2_account_info.main.s3_api_url, "https://")}/${b2_bucket.restic.bucket_name}"
}
