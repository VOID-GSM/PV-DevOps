output "alarm_names" {
  value = concat(
    [for a in aws_cloudwatch_metric_alarm.ec2 : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.health : a.alarm_name],
  )
}