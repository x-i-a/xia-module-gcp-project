variable "project_file" {
  type = string
  description = "Project config file"
}

variable "landscape_file" {
  type = string
  description = "Landscape file"
}

variable "applications_file" {
  type = string
  description = "Application config file"
}

variable "app_env_config" {
  type = map(any)
  description = "Application Environment Configuration"
}

