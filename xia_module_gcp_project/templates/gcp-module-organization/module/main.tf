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
  for_each = local.level_1_realms
  display_name = each.value.name
  parent       = "organizations/${data.google_organization.cosmos_org.org_id}"
}

resource "google_folder" "realm_l2_folders" {
  for_each = local.level_2_realms
  display_name = each.value.name
  parent       = google_folder.realm_l1_folders[each.value.parent].name
}

resource "google_folder" "realm_l3_folders" {
  for_each = local.level_3_realms
  display_name = each.value.name
  parent       = google_folder.realm_l2_folders[each.value.parent].name
}

resource "google_folder" "foundation_folders" {
  for_each = local.all_foundations
  display_name = each.value.name
  parent       = coalesce(
    lookup(lookup(google_folder.realm_l1_folders, each.value.parent, {}), "name", ""),
    lookup(lookup(google_folder.realm_l2_folders, each.value.parent, {}), "name", ""),
    lookup(lookup(google_folder.realm_l3_folders, each.value.parent, {}), "name", ""),
    "organizations/${data.google_organization.cosmos_org.org_id}"
  )
}

resource "google_service_account" "foundation_admin_sa" {
  for_each = local.all_foundations
  project      = local.cosmos_project
  account_id   = "dir-${each.value.name}-sa"
  display_name = "Service Account for Foundation Directory ${each.value["name"]}"
  depends_on = [google_folder.foundation_folders]
}

resource "google_folder_iam_member" "foundation_admin_sa_owner" {
  for_each = local.all_foundations
  folder = google_folder.foundation_folders[each.key].name
  role = "roles/owner"
  member = "serviceAccount:${google_service_account.foundation_admin_sa[each.key].email}"
}