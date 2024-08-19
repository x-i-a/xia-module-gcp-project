terraform {
  required_providers {
    github = {
      source  = "integrations/github"
    }
  }
}

provider "github" {
  owner = lookup(var.github_config, "github_owner", null)
}