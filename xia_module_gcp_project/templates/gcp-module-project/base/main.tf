module "gcp_module_project" {
  source = "../../modules/gcp-module-project"

  project_file = "../../../config/gcp-project.yaml"
  landscape_file = "../../../config/landscape.yaml"
  applications_file = "../../../config/applications.yaml"

  depends_on = [module.gh_module_application]
}
