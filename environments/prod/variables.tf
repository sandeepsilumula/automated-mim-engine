variable "environment" {
  type    = string
  default = "prod"
}

variable "incident_email" {
  type        = string
  description = "The target email address for Major Incident notifications"
}