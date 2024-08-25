provider "google" {
  alias = "google-gcp-project"
}

provider "github" {
  alias = "github-gcp-project"
  owner = lookup(yamldecode(file("../../../config/core/github.yaml")), "github_owner", null)
}

module "gcp_module_project" {
  providers = {
    google = google.google-gcp-project
    github = github.github-gcp-project
  }

  source = "../../modules/gcp-module-project"

  module_name = "gcp-module-project"
  config_file = "../../../config/platform/gcp-project.yaml"
  landscape = local.landscape
  applications = local.applications
  modules = local.modules
  environment_dict = local.environment_dict
  app_env_config = local.app_env_config
  module_app_to_activate = local.module_app_to_activate
  github_config = module.gh_module_application.github_config

  depends_on = [module.gh_module_application]
}
