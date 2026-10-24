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