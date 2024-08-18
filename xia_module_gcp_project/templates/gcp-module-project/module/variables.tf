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

variable "module_name" {
  type = string
  description = "Module Name"
}

variable "config_file" {
  type = string
  description = "Project config file"
}

variable "environment_dict" {
  type = map(any)
  description = "Environment Configuration"
}

variable "app_env_config" {
  type = map(any)
  description = "Application Environment Configuration"
}

variable "module_app_to_activate" {
  type = map(list(any))
  description = "Application to be activated for all modules"
}

