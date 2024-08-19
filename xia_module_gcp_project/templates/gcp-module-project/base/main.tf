provider "github" {
  owner = lookup(yamldecode(file("../../../config/core/github.yaml"))["settings"], "github_owner", null)
}

module "gcp_module_project" {
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
