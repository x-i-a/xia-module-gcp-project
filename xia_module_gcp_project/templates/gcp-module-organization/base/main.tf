provider "google" {
  alias = "google-gcp-org"
}

provider "github" {
  alias = "github-gcp-org"
}

module "gcp_module_organization" {
  providers = {
    google = google.google-gcp-org
    github = github.github-gcp-org
  }

  source = "../../modules/gcp-module-organization"

  landscape = local.landscape
  level_1_realms = local.level_1_realms
  level_2_realms = local.level_2_realms
  level_3_realms = local.level_3_realms
  foundations = local.foundations
}
