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
  cosmos_name = local.settings["cosmos_name"]
  cosmos_project = local.settings["cosmos_project"]
}

resource "google_service_account" "cosmos_admin_sa" {
  project      = local.cosmos_project
  account_id   = "cosmos-admin-sa"
  display_name = "Cosmos Administrator Service Account"
}

resource "google_project_iam_member" "cosmos_admin_sa_owner" {
  project = local.cosmos_project
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.cosmos_admin_sa.email}"
}

resource "google_iam_workload_identity_pool" "github_pool" {

  workload_identity_pool_id = "wip-cosmos"
  project  = local.cosmos_project

  # Workload Identity Pool configuration
  display_name = "wip-cosmos"
  description  = "Pool for GitHub Actions of Cosmos"

  # Make sure the pool is in a state to be used
  disabled = false

}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id     = "ghp-cosmos"
  project  = local.cosmos_project

  # Provider configuration specific to GitHub
  display_name = "ghp-cosmos"
  description  = "Provider for GitHub Actions of Cosmos"

   # Attribute mapping / condition from the OIDC token to Google Cloud attributes
  attribute_condition = "assertion.repository == '${var.repository_owner}/${local.cosmos_name}'"

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
  service_account_id = google_service_account.cosmos_admin_sa.id
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.repository_owner}/${local.cosmos_name}"
  ]
}

resource "github_actions_variable" "var_project_id" {
  repository       = local.cosmos_name
  variable_name    = "PROJECT_ID"
  value            = local.cosmos_project
}

resource "github_actions_variable" "var_wip_name" {
  repository       = local.cosmos_name
  variable_name    = "SECRET_WIP_NAME"
  value            = google_iam_workload_identity_pool_provider.github_provider.name
}

resource "github_actions_variable" "var_sa_email" {
  repository       = local.cosmos_name
  variable_name    = "PROVIDER_SA_EMAIL"
  value            = google_service_account.cosmos_admin_sa.email
}