module "gcp_module_project" {
  source = "../../modules/gcp-module-project"

  project_file = "../../../config/gcp-project.yaml"
  landscape_file = "../../../config/landscape.yaml"
  applications_file = "../../../config/applications.yaml"

  module_name = "gcp-module-project"
  environment_dict = local.environment_dict
  app_env_config = local.app_env_config
  app_to_activate = lookup(local.module_app_to_activate, module_name, [])

  depends_on = [module.gh_module_application]
}
