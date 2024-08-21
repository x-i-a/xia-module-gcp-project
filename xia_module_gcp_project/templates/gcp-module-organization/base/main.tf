module "gcp_module_organization" {
  source = "../../modules/gcp-module-organization"

  module_name = "gcp-module-organization"
  landscape = local.landscape
  level_1_realms = local.level_1_realms
  level_2_realms = local.level_2_realms
  level_3_realms = local.level_3_realms
  foundations = local.foundations
}
