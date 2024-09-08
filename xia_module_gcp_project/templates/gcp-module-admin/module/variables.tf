variable "module_name" {
  type = string
  description = "Module Name"
  default = null
}

variable "config_file" {
  type = string
  description = "Project config file"
  default = ""
}

variable "landscape" {
  type = any
  description = "Landscape Configuration"
}

variable "repository_owner" {
  type = any
  description = "Github repository Owner"
}

