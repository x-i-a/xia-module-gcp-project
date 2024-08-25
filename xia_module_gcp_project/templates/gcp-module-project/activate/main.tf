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
  module_name = coalesce(var.module_name, substr(basename(path.module), 9, length(basename(path.module)) - 9))
}

resource "google_folder_iam_member" "foundation_admin_sa_owner" {
  for_each = var.foundations
  folder = var.foundation_folders[each.key].name
  role = "roles/owner"
  member = "serviceAccount:${var.foundation_admin_sa[each.key].email}"
}
