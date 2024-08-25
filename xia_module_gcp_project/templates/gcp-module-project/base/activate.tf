provider "google" {
  alias = "activate-google-gcp-project"
}

provider "github" {
  alias = "activate-github-gcp-project"
  owner = lookup(yamldecode(file("../../../config/core/github.yaml")), "github_owner", null)
}

module "activate_gcp_module_project" {
  providers = {
    google = google.activate-google-gcp-project
    github = github.activate-github-gcp-project
  }

  source = "../../modules/activate-gcp-module-project"

  landscape = local.landscape
  level_1_realms = local.level_1_realms
  level_2_realms = local.level_2_realms
  level_3_realms = local.level_3_realms
  foundations = local.foundations

  foundation_folders = module.gcp_module_organization.foundation_folders
  foundation_admin_sa = module.gcp_module_organization.foundation_admin_sa
  depends_on = [module.gcp_module_organization]
}
