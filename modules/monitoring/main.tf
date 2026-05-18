resource "aws_cloudwatch_metric_alarm" "major_incident_alarm" {
  alarm_name          = "${var.environment}-major-incident-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "CustomApplication/MIM"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Fires when critical error counts breach SLAs."
  treat_missing_data  = "notBreaching"
}