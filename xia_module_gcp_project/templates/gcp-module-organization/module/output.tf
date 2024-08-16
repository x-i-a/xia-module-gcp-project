output "foundation_admin_sa" {
  value = { for key, sa in google_service_account.foundation_admin_sa : key => { email = sa.email } }
}
