variable "postgres_chart_version" {
  type    = string
  default = "15.5.21"
}

variable "postgres_image_tag" {
  type    = string
  default = "16.4.0-debian-12-r0"
}

variable "app_version" {
  type        = string
  description = "Managed by Jenkins"
}

variable "db_user_dev" {
  type      = string
  sensitive = true
}

variable "db_password_dev" {
  type      = string
  sensitive = true
}