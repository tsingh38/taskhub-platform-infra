variable "prometheus_chart_version" {
  type    = string
  default = "56.6.2"
}

variable "slack_webhook_url" {
  type      = string
  sensitive = true
}