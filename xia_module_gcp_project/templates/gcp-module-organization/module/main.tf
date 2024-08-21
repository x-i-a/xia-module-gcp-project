terraform {
  required_providers {
    github = {
      source  = "integrations/github"
    }
  }
}

data "google_organization" "cosmos_org" {
  domain = local.cosmos_org
}

locals {
  landscape = var.landscape
  settings = lookup(local.landscape, "settings", {})
  cosmos_org = local.settings["cosmos_org"]
  cosmos_name = local.settings["cosmos_name"]
  cosmos_bucket = lookup(local.settings, "cosmos_bucket", local.cosmos_name)
  cosmos_project = local.settings["cosmos_project"]
  structure = local.landscape["structure"]
  github_owner = lookup(local.settings, "github_owner", "")
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

resource "google_folder_iam_member" "foundation_admin_sa_owner" {
  for_each = var.foundations
  folder = google_folder.foundation_folders[each.key].name
  role = "roles/owner"
  member = "serviceAccount:${google_service_account.foundation_admin_sa[each.key].email}"
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
  attribute_condition = "assertion.sub == 'repo:${local.github_owner}/${each.value["repository_name"]}' && assertion.ref.matches('main')"

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
