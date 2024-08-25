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
  applications = var.applications
  settings = lookup(var.landscape, "settings", {})
  cosmos_name = local.settings["cosmos_name"]
  realm_name = local.settings["realm_name"]
  foundation_name = local.settings["foundation_name"]
  tf_bucket_name = lookup(local.settings, "cosmos_name")
  app_to_activate = lookup(var.module_app_to_activate, var.module_name, [])
  pool_configuration = { for k, v in var.app_env_config : k => v if contains(local.app_to_activate, v["app_name"]) }
}

locals {
  project_config = yamldecode(file(var.config_file))
  folder_id = lookup(local.project_config, "folder_id", null)
  project_prefix = local.project_config["project_prefix"]
  billing_account = local.project_config["billing_account"]
}

resource "google_project" "env_projects" {
  for_each = var.environment_dict

  name = "${local.project_prefix}${each.key}"
  project_id = "${local.project_prefix}${each.key}"
  folder_id = local.folder_id
  billing_account = local.billing_account
}

resource "google_project_service" "service_usage_api" {
  for_each = var.environment_dict

  project = google_project.env_projects[each.key].project_id
  service = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_resource_manager_api" {
  for_each = var.environment_dict

  project = google_project.env_projects[each.key].project_id
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "identity_and_access_manager_api" {
  for_each = var.environment_dict

  project = google_project.env_projects[each.key].project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_iam_workload_identity_pool" "github_pool" {
  for_each = local.pool_configuration

  workload_identity_pool_id = "gh-${each.value["repository_name"]}"
  project  = google_project.env_projects[each.value["env_name"]].project_id

  # Workload Identity Pool configuration
  display_name = "gh-${each.value["repository_name"]}"
  description  = "Pool for GitHub Actions of ${each.value["repository_name"]}"

  # Make sure the pool is in a state to be used
  disabled = false

  depends_on = [google_project_service.cloud_resource_manager_api]
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  for_each = local.pool_configuration

  workload_identity_pool_id = google_iam_workload_identity_pool.github_pool[each.key].workload_identity_pool_id
  workload_identity_pool_provider_id     = "ghp-${each.value["repository_name"]}"
  project  = google_project.env_projects[each.value["env_name"]].project_id

  # Provider configuration specific to GitHub
  display_name = "ghp-${each.value["repository_name"]}"
  description  = "Provider for GitHub Actions of ${each.value["repository_name"]}"

   # Attribute mapping / condition from the OIDC token to Google Cloud attributes
  attribute_condition = "assertion.sub == 'repo:${each.value["repository_owner"]}/${each.value["repository_name"]}:environment:${each.value["env_name"]}' && assertion.ref.matches('${each.value["match_branch"]}') && assertion.event_name.matches('${each.value["match_event"]}')"

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

resource "google_service_account" "github_provider_sa" {
  for_each = local.pool_configuration
  project      = google_project.env_projects[each.value["env_name"]].project_id
  account_id   = "wip-${each.value["app_name"]}-sa"
  display_name = "Service Account for Identity Pool provider of ${each.value["app_name"]}"

  depends_on = [google_project_service.cloud_resource_manager_api, google_project_service.identity_and_access_manager_api]
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  for_each = local.pool_configuration
  service_account_id = google_service_account.github_provider_sa[each.key].id
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool[each.key].name}/attribute.repository/${each.value["repository_owner"]}/${each.value["repository_name"]}"
  ]
}

resource "github_actions_environment_variable" "action_var_cosmos_name" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "COSMOS_NAME"
  value            = local.cosmos_name
}

resource "github_actions_environment_variable" "action_var_realm_name" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "REALM_NAME"
  value            = local.realm_name
}

resource "github_actions_environment_variable" "action_var_foundation_name" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "FOUNDATION_NAME"
  value            = local.foundation_name
}

resource "github_actions_environment_variable" "action_var_app_name" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "APP_NAME"
  value            = each.value["app_name"]
}

resource "github_actions_environment_variable" "action_var_project_id" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "PROJECT_ID"
  value            = google_project.env_projects[each.value["env_name"]].project_id
}

resource "github_actions_environment_variable" "action_var_env_name" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "ENV_NAME"
  value            = each.value["env_name"]
}

resource "github_actions_environment_variable" "action_var_wip_name" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "SECRET_WIP_NAME"
  value            = google_iam_workload_identity_pool_provider.github_provider[each.key].name
}

resource "github_actions_environment_variable" "action_var_sa_email" {
  for_each = local.pool_configuration

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "PROVIDER_SA_EMAIL"
  value            = google_service_account.github_provider_sa[each.key].email
}
