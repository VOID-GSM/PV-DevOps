# 알림 허브: 모든 알림(CloudWatch 알람, 예산, 백업 실패)이 이 토픽으로 모이고
# 구독한 Lambda가 Discord로 전달
data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "this" {
  name = "${var.name}-alarms"
}

resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.this.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # 기본 정책과 동일: 이 계정 안에서는 사용 가능 (CloudWatch 알람 포함)
        Sid       = "AccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action = [
          "SNS:Publish", "SNS:Subscribe", "SNS:GetTopicAttributes", "SNS:SetTopicAttributes",
          "SNS:ListSubscriptionsByTopic", "SNS:AddPermission", "SNS:RemovePermission", "SNS:DeleteTopic",
        ]
        Resource  = aws_sns_topic.this.arn
        Condition = { StringEquals = { "AWS:SourceOwner" = data.aws_caller_identity.current.account_id } }
      },
      { # 예산(Budgets), 백업 실패 이벤트(EventBridge)는 서비스 주체로 게시하므로 따로 허용
        Sid       = "AwsServicesPublish"
        Effect    = "Allow"
        Principal = { Service = ["budgets.amazonaws.com", "events.amazonaws.com"] }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.this.arn
        Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
      },
    ]
  })
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "lambda"
  endpoint  = var.subscriber_function_arn
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.subscriber_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.this.arn
}