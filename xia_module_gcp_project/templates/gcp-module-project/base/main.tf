module "gcp_module_project" {
  source = "../../modules/gcp-module-project"

  project_file = "../../../config/gcp-project.yaml"
  landscape_file = "../../../config/landscape.yaml"
  applications_file = "../../../config/applications.yaml"

  app_env_config = local.app_env_config
  app_to_activate = lookup(local.module_app_to_activate, "gcp-module-project", [])

  depends_on = [module.gh_module_application]
}
