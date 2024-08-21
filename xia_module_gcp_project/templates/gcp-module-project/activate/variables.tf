variable "module_name" {
  type = string
  description = "Module Name"
  default = ""
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

variable "foundations" {
  type = map(any)
  description = "Foundation Configuration"
}

variable "level_1_realms" {
  type = map(any)
  description = "Level 1 Realm Configuration"
}

variable "level_2_realms" {
  type = map(any)
  description = "Level 2 Realm  Configuration"
}

variable "level_3_realms" {
  type = map(any)
  description = "Level 3 Realm  Configuration"
}

variable "foundation_folders" {
  type = map(map(any))
  description = "Foundation Folders"
}

variable "foundation_admin_sa" {
  type = map(map(any))
  description = "Foundation admin service account dict"
}
