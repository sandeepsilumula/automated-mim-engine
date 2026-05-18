module "monitoring" {
  source      = "../../modules/monitoring"
  environment = var.environment
}

module "incident_response" {
  source               = "../../modules/incident_response"
  environment          = var.environment
  monitored_alarm_name = module.monitoring.alarm_name
  incident_email       = var.incident_email # <- Ensure this line matches perfectly
}