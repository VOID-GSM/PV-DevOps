# EC2 상태 알람 + 서비스 헬스체크(5분마다) 알람 → SNS
data "aws_region" "current" {}

locals {
  automate = "arn:aws:automate:${data.aws_region.current.region}:ec2"
  ec2_alarms = {
    system-check = {
      metric    = "StatusCheckFailed_System", stat = "Maximum", op = "GreaterThanOrEqualToThreshold"
      threshold = 1, period = 60, periods = 2, actions = ["${local.automate}:recover"]
    }
    instance-check = {
      metric    = "StatusCheckFailed_Instance", stat = "Maximum", op = "GreaterThanOrEqualToThreshold"
      threshold = 1, period = 60, periods = 3, actions = ["${local.automate}:reboot"]
    }
    cpu-high = { # 10분 연속 CPU 80% 초과
      metric    = "CPUUtilization", stat = "Average", op = "GreaterThanThreshold"
      threshold = 80, period = 300, periods = 2, actions = []
    }
    cpu-credit-low = {
      metric    = "CPUCreditBalance", stat = "Minimum", op = "LessThanThreshold"
      threshold = 30, period = 300, periods = 1, actions = []
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2" {
  for_each = local.ec2_alarms

  alarm_name          = "${var.name}-${each.key}"
  namespace           = "AWS/EC2"
  metric_name         = each.value.metric
  statistic           = each.value.stat
  comparison_operator = each.value.op
  threshold           = each.value.threshold
  period              = 60
  evaluation_periods  = each.value.periods
  dimensions          = { InstanceId = var.instance_id }
  alarm_actions       = concat(each.value.actions, [var.alarm_topic_arn])
  ok_actions          = [var.alarm_topic_arn]
}

resource "aws_cloudwatch_event_rule" "health_check" {
  name                = "${var.name}-health-check"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "health_check" {
  rule = aws_cloudwatch_event_rule.health_check.name
  arn  = var.health_check_function_arn
  input = jsonencode({
    namespace = var.health_check_namespace
    targets   = var.health_check_targets
  })
}

resource "aws_lambda_permission" "health_check" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.health_check_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.health_check.arn
}

resource "aws_cloudwatch_metric_alarm" "health" {
  for_each = var.health_check_targets

  alarm_name          = "${var.name}-health-${each.key}"
  namespace           = var.health_check_namespace
  metric_name         = "Success"
  dimensions          = { Target = each.key }
  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 2
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
}