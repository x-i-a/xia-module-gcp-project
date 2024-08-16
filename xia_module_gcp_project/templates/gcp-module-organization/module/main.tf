terraform {
  required_providers {
    github = {
      source  = "integrations/github"
    }
  }
}

locals {
  landscape = yamldecode(file(var.landscape_file))
  settings = lookup(local.landscape, "settings", {})
  cosmos_org = local.settings["cosmos_org"]
  cosmos_project = local.settings["cosmos_project"]
  cosmos_name = local.settings["cosmos_name"]
  structure = local.landscape["structure"]
}

locals {
  level_0_foundations = {
    for foundation, details in lookup(local.structure, "foundations", {}) : foundation => {
      name = foundation
      parent = "root"
    }
  }

  level_1_realms = {
    for realm, details in lookup(local.structure, "realms", {}) : realm => {
      name = realm
      parent = "root"
    }
  }

  level_1_foundations = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for foundation, foundation_details in lookup(details, "foundations", {}) : {
          realm = realm
          foundation = foundation
        }
      ]
    ]) : "${pair.realm}/${pair.foundation}" => {
      parent = pair.realm
      name = pair.foundation
    }
  }

  level_2_realms = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : {
          realm = realm
          sub_realm = sub_realm
        }
      ]
    ]) : "${pair.realm}/${pair.sub_realm}" => {
      parent = pair.realm
      name = pair.sub_realm
    }
  }

  level_2_foundations = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : [
          for foundation, foundation_details in lookup(sub_details, "foundations", {}) : {
            realm = realm
            sub_realm = sub_realm
            foundation = foundation
          }
        ]
      ]
    ]) : "${pair.realm}/${pair.sub_realm}/${pair.foundation}" => {
      parent = "${pair.realm}/${pair.sub_realm}"
      name = pair.foundation
    }
  }

  level_3_realms = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : [
          for bis_realm, bis_details in lookup(sub_details, "realms", {}) : {
            realm = realm
            sub_realm = sub_realm
            bis_realm = bis_realm
          }
        ]
      ]
    ]) : "${pair.realm}/${pair.sub_realm}/${pair.bis_realm}" => {
      parent = "${pair.realm}/${pair.sub_realm}"
      name = pair.bis_realm
    }
  }

  level_3_foundations = {
    for idx, pair in flatten([
      for realm, details in lookup(local.structure, "realms", {}) : [
        for sub_realm, sub_details in lookup(details, "realms", {}) : [
          for bis_realm, bis_details in lookup(sub_details, "realms", {}) : [
            for foundation, foundation_details in lookup(bis_details, "foundations", {}) : {
              realm = realm
              sub_realm = sub_realm
              bis_realm = bis_realm
              foundation = foundation
            }
          ]
        ]
      ]
    ]) : "${pair.realm}/${pair.sub_realm}/${pair.bis_realm}/${pair.foundation}" => {
      parent = "${pair.realm}/${pair.sub_realm}/${pair.bis_realm}"
      name = pair.foundation
    }
  }

  all_realms = merge(local.level_1_realms, local.level_2_realms, local.level_3_realms)
  all_foundations = merge(local.level_0_foundations, local.level_1_foundations, local.level_2_foundations, local.level_3_foundations)
}

data "google_organization" "cosmos_org" {
  domain = local.cosmos_org
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