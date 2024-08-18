module "gcp_module_project" {
  source = "../../modules/gcp-module-project"

  module_name = "gcp-module-project"
  config_file = "../../../config/infra/gcp-project.yaml"
  landscape = local.landscape
  applications = local.applications
  environment_dict = local.environment_dict
  app_env_config = local.app_env_config
  module_app_to_activate = local.module_app_to_activate

  depends_on = [module.gh_module_application]
}
