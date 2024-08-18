output "gcp_projects" {
  value = { for key, project in google_project.env_projects : key => { project_id = project.project_id } }
}

output "github_provider_sa" {
  value = { for key, sa in google_service_account.github_provider_sa : key => { email = sa.email } }
}
