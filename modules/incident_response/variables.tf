variable "environment" {
  type = string
}

variable "monitored_alarm_name" {
  type = string
}

variable "incident_email" {
  type        = string
  description = "The incoming email string from the root configuration"
}