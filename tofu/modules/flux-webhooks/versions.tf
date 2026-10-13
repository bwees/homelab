terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    random = {
      source = "hashicorp/random"
    }
    onepassword = {
      source = "1Password/onepassword"
    }
  }
}
