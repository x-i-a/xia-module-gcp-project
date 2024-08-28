terraform {
  required_providers {
    github = {
      source  = "integrations/github"
    }
    google = {
      source  = "hashicorp/google"
    }
  }
}

locals {
  module_name = coalesce(var.module_name, basename(path.module))
  landscape = var.landscape
  settings = lookup(local.landscape, "settings", {})
}

locals {
  org_config = yamldecode(file(var.config_file))
  cosmos_org = local.org_config["cosmos_org"]
  cosmos_name = local.org_config["cosmos_name"]
  cosmos_project = local.org_config["cosmos_project"]
}

data "google_organization" "cosmos_org" {
  domain = local.cosmos_org
}

resource "google_project_service" "service_usage_api" {
  project = local.cosmos_project
  service = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_resource_manager_api" {
  project = local.cosmos_project
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "identity_and_access_manager_api" {
  project = local.cosmos_project
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_folder" "realm_l1_folders" {
  for_each = var.level_1_realms
  display_name = each.value["name"]
  parent       = "organizations/${data.google_organization.cosmos_org.org_id}"
}

resource "google_folder" "realm_l2_folders" {
  for_each = var.level_2_realms
  display_name = each.value["name"]
  parent       = google_folder.realm_l1_folders[each.value["parent"]].name
}

resource "google_folder" "realm_l3_folders" {
  for_each = var.level_3_realms
  display_name = each.value["name"]
  parent       = google_folder.realm_l2_folders[each.value["parent"]].name
}

resource "google_folder" "foundation_folders" {
  for_each = var.foundations
  display_name = each.value["name"]
  parent       = coalesce(
    lookup(lookup(google_folder.realm_l1_folders, each.value["parent"], {}), "name", ""),
    lookup(lookup(google_folder.realm_l2_folders, each.value["parent"], {}), "name", ""),
    lookup(lookup(google_folder.realm_l3_folders, each.value["parent"], {}), "name", ""),
    "organizations/${data.google_organization.cosmos_org.org_id}"
  )
}

resource "google_service_account" "foundation_admin_sa" {
  for_each = var.foundations
  project      = local.cosmos_project
  account_id   = "adm-${each.value["name"]}-sa"
  display_name = "Service Account for Foundation Directory ${each.value["name"]}"
  depends_on = [google_folder.foundation_folders]
}

resource "google_iam_workload_identity_pool" "github_pool" {
  for_each = var.foundations

  workload_identity_pool_id = "wip-${each.value["name"]}"
  project  = local.cosmos_project

  # Workload Identity Pool configuration
  display_name = "wip-${each.value["name"]}"
  description  = "Pool for GitHub Actions of ${each.value["name"]}"

  # Make sure the pool is in a state to be used
  disabled = false

  depends_on = [google_project_service.cloud_resource_manager_api]
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  for_each = var.foundations

  workload_identity_pool_id = google_iam_workload_identity_pool.github_pool[each.key].workload_identity_pool_id
  workload_identity_pool_provider_id     = "ghp-${each.value["name"]}"
  project  = local.cosmos_project

  # Provider configuration specific to GitHub
  display_name = "ghp-${each.value["name"]}"
  description  = "Provider for GitHub Actions of ${each.value["name"]}"

   # Attribute mapping / condition from the OIDC token to Google Cloud attributes
  attribute_condition = "assertion.repository == '${each.value["repository_owner"]}/${each.value["repository_name"]}'"

  attribute_mapping = {
    "google.subject" = "assertion.sub",
    "attribute.actor" = "assertion.actor",
    "attribute.event_name" = "assertion.event_name",
    "attribute.repository" = "assertion.repository",
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref" = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  for_each = var.foundations
  service_account_id = google_service_account.foundation_admin_sa[each.key].id
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool[each.key].name}/attribute.repository/${each.value["repository_owner"]}/${each.value["repository_name"]}"
  ]
}

resource "github_actions_variable" "var_project_id" {
  for_each         = var.foundations

  repository       = each.value["repository_name"]
  variable_name    = "PROJECT_ID"
  value            = local.cosmos_project
}

resource "github_actions_variable" "var_wip_name" {
  for_each         = var.foundations

  repository       = each.value["repository_name"]
  variable_name    = "SECRET_WIP_NAME"
  value            = google_iam_workload_identity_pool_provider.github_provider[each.key].name
}

resource "github_actions_variable" "var_sa_email" {
  for_each         = var.foundations

  repository       = each.value["repository_name"]
  variable_name    = "PROVIDER_SA_EMAIL"
  value            = google_service_account.foundation_admin_sa[each.key].email
}