output "foundation_admin_sa" {
  value = { for key, sa in google_service_account.foundation_admin_sa : key => { email = sa.email } }
}

output "foundation_folders" {
  value = { for key, folder in google_folder.foundation_folders : key => { name = folder.name } }
}