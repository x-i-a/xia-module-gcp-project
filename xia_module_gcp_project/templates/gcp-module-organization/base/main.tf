module "gcp_module_organization" {
  source = "../../modules/gcp-module-organization"

  landscape_file = "../../../config/landscape.yaml"
}
