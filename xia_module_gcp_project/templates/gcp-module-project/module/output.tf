output "github_provider_sa" {
  value = { for key, sa in google_service_account.github_provider_sa : key => { email = sa.email } }
}
