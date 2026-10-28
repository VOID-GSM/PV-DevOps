resource "aws_backup_vault" "this" {
  name = "${var.name}-vault"
}

resource "aws_backup_plan" "this" {
  name = "${var.name}-daily"
  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.schedule
    lifecycle {
      delete_after = var.retention_days
    }
  }
}

resource "aws_iam_role" "backup" {
  name = "${var.name}-backup"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
    "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores",
  ])
  role       = aws_iam_role.backup.name
  policy_arn = each.value
}

resource "aws_backup_selection" "tagged" {
  name         = "${var.name}-tagged"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "daily"
  }
}

# 백업 실패 알림: AWS Backup 이벤트 중 실패만 골라 SNS로 보냄
resource "aws_cloudwatch_event_rule" "backup_failed" {
  name = "${var.name}-backup-failed"
  event_pattern = jsonencode({
    source        = ["aws.backup"]
    "detail-type" = ["Backup Job State Change"]
    detail        = { state = ["FAILED", "ABORTED", "EXPIRED"] }
  })
}

resource "aws_cloudwatch_event_target" "backup_failed" {
  rule = aws_cloudwatch_event_rule.backup_failed.name
  arn  = var.alarm_topic_arn

  # Discord 알림 Lambda가 읽기 좋은 형태로 바꿔서 보냄
  input_transformer {
    input_paths = {
      state    = "$.detail.state"
      reason   = "$.detail.statusMessage"
      resource = "$.detail.resourceArn"
    }
    input_template = <<-EOT
      {"title": "❌ 백업 실패 (<state>)", "description": "<reason>", "resource": "<resource>"}
    EOT
  }
}