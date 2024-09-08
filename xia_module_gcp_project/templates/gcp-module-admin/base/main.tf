provider "google" {
  alias = "google-gcp-admin"
}

provider "github" {
  alias = "github-gcp-admin"
  owner = lookup(yamldecode(file("../../../config/core/github.yaml")), "github_owner", null)
}

module "gcp_module_admin" {
  providers = {
    google = google.google-gcp-admin
    github = github.github-gcp-admin
  }

  source = "../../modules/gcp-module-admin"

  landscape = local.landscape
  repository_owner = lookup(yamldecode(file("../../../config/core/github.yaml")), "github_owner", null)
}
