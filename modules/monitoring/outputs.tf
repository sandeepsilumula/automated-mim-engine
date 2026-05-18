output "alarm_name" {
  value       = aws_cloudwatch_metric_alarm.major_incident_alarm.alarm_name
  description = "The unique text string name of the monitored CloudWatch Alarm"
}