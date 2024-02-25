terraform {
  required_providers {
    github = {
      source  = "integrations/github"
    }
  }
}

locals {
  project = yamldecode(file(var.project_file))
  landscape = yamldecode(file(var.landscape_file))
  applications = yamldecode(file(var.applications_file))
  folder_id = lookup(local.project, "folder_id", null)
  project_prefix = local.project["project_prefix"]
  billing_account = local.project["billing_account"]
  environment_dict = local.landscape["environments"]
  activated_apps = lookup(lookup(local.landscape["modules"], "gcp_module_project", {}), "applications", [])
}

locals {
  filtered_applications = { for app_name, app in local.applications : app_name => app if contains(local.activated_apps, app_name) }

  all_pool_settings = toset(flatten([
    for app_name, app in local.filtered_applications : [
      for env_name, env in local.environment_dict : {
        app_name          = app_name
        env_name          = env_name
        repository_owner  = app["repository_owner"]
        repository_name   = app["repository_name"]
        project_id        = "${local.project_prefix}${env_name}"
        match_branch      = env["match_branch"]
      }
    ]
  ]))
}

resource "google_project" "env_projects" {
  for_each = local.environment_dict

  name = "${local.project_prefix}${each.key}"
  project_id = "${local.project_prefix}${each.key}"
  folder_id = local.folder_id
  billing_account = local.billing_account
}

resource "google_project_service" "cloud_resource_manager_api" {
  for_each = local.environment_dict

  project = google_project.env_projects[each.key].project_id
  service = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "identity_and_access_manager_api" {
  for_each = local.environment_dict

  project = google_project.env_projects[each.key].project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "tfstate-bucket" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }

  project       = local.landscape["settings"]["cosmos_name"]
  name          = "${local.landscape["settings"]["realm_name"]}_${each.value["app_name"]}_${each.value["env_name"]}"
  location      = local.landscape["settings"]["foundation_region"]
  force_destroy = true
}

resource "google_iam_workload_identity_pool" "github_pool" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }

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
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }

  workload_identity_pool_id = google_iam_workload_identity_pool.github_pool[each.key].workload_identity_pool_id
  workload_identity_pool_provider_id     = "ghp-${each.value["repository_name"]}"
  project  = each.value["project_id"]

  # Provider configuration specific to GitHub
  display_name = "ghp-${each.value["repository_name"]}"
  description  = "Provider for GitHub Actions of ${each.value["repository_name"]}"

   # Attribute mapping / condition from the OIDC token to Google Cloud attributes
  attribute_condition = "assertion.sub == 'repo:${each.value["repository_owner"]}/${each.value["repository_name"]}:environment:${each.value["env_name"]}' && assertion.ref.matches('${each.value["match_branch"]}')"

  attribute_mapping = {
    "google.subject" = "assertion.sub",
    "attribute.actor" = "assertion.actor",
    "attribute.repository" = "assertion.repository",
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref" = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_provider_sa" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }
  project      = google_project.env_projects[each.value["env_name"]].project_id
  account_id   = "wip-${each.value["app_name"]}-sa"
  display_name = "Service Account for Identity Pool provider of ${each.value["app_name"]}"

  depends_on = [google_project_service.cloud_resource_manager_api, google_project_service.identity_and_access_manager_api]
}

resource "google_service_account_iam_binding" "workload_identity_binding" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }
  service_account_id = google_service_account.github_provider_sa[each.key].id
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool[each.key].name}/attribute.repository/${each.value["repository_owner"]}/${each.value["repository_name"]}"
  ]
}

resource "google_storage_bucket_iam_member" "tfstate_bucket_assign" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }
  bucket = google_storage_bucket.tfstate-bucket[each.key].id
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.github_provider_sa[each.key].email}"
}


resource "github_actions_environment_variable" "action_var_project_id" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "PROJECT_ID"
  value            = each.value["project_id"]
}

resource "github_actions_environment_variable" "action_var_wip_name" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "SECRET_WIP_NAME"
  value            = google_iam_workload_identity_pool_provider.github_provider[each.key].name
}

resource "github_actions_environment_variable" "action_var_sa_email" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "PROVIDER_SA_EMAIL"
  value            = google_service_account.github_provider_sa[each.key].email
}

resource "github_actions_environment_variable" "action_var_tf_bucket" {
  for_each = { for s in local.all_pool_settings : "${s.app_name}-${s.env_name}" => s }

  repository       = each.value["repository_name"]
  environment      = each.value["env_name"]
  variable_name    = "TF_BUCKET_NAME"
  value            = google_storage_bucket.tfstate-bucket[each.key].id
}