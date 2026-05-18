variable "environment" {
  type    = string
  default = "prod"
}

variable "incident_email" {
  description = "Email address for incident notifications"
  type        = string
}