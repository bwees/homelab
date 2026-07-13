terraform {
  backend "s3" {
    bucket = "tofu"
    key    = "terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://5e2ba2ec4aedeea294c2bf45f28c6414.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
