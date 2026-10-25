# EC2 상태 알람 + 서비스 헬스체크(5분마다) 알람 → SNS
data "aws_region" "current" {}

locals {
  automate = "arn:aws:automate:${data.aws_region.current.region}:ec2"
  ec2_alarms = {
    system-check = {
      desc      = "서버 하드웨어"
      metric    = "StatusCheckFailed_System", stat = "Maximum", op = "GreaterThanOrEqualToThreshold"
      threshold = 1, period = 60, periods = 2, actions = ["${local.automate}:recover"]
    }
    instance-check = {
      desc      = "서버 OS 응답"
      metric    = "StatusCheckFailed_Instance", stat = "Maximum", op = "GreaterThanOrEqualToThreshold"
      threshold = 1, period = 60, periods = 3, actions = ["${local.automate}:reboot"]
    }
    cpu-high = { # 10분 연속 CPU 80% 초과
      desc      = "CPU 사용률"
      metric    = "CPUUtilization", stat = "Average", op = "GreaterThanThreshold"
      threshold = 80, period = 300, periods = 2, actions = []
    }
    cpu-credit-low = {
      desc      = "CPU 크레딧"
      metric    = "CPUCreditBalance", stat = "Minimum", op = "LessThanThreshold"
      threshold = 30, period = 300, periods = 1, actions = []
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2" {
  for_each = local.ec2_alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = each.value.desc
  namespace           = "AWS/EC2"
  metric_name         = each.value.metric
  statistic           = each.value.stat
  comparison_operator = each.value.op
  threshold           = each.value.threshold
  period              = each.value.period
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

# 3칸(15분) 중 2칸 실패해야 장애. 실행 시각이 밀려 빈 칸이 하나 생겨도 오탐하지 않음
resource "aws_cloudwatch_metric_alarm" "health" {
  for_each = var.health_check_targets

  alarm_name          = "${var.name}-health-${each.key}"
  alarm_description   = lookup({ api = "API 서버 접속", web = "웹 페이지 접속" }, each.key, "${each.key} 접속")
  namespace           = var.health_check_namespace
  metric_name         = "Success"
  dimensions          = { Target = each.key }
  statistic           = "Minimum"
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  treat_missing_data  = "breaching"
  alarm_actions       = [var.alarm_topic_arn]
  ok_actions          = [var.alarm_topic_arn]
}