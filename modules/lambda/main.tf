locals {
  module_file = trimsuffix(basename(var.source_file), ".py")
}

data "archive_file" "this" {
  type = "zip"
  source_file = var.source_file
  output_path = "${path.root}/.build/${var.name}.zip"
}

resource "aws_iam_role" "this" {
  name = var.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "lambda.amazonaws.com" }}]
  })
}

resource "aws_iam_role_policy" "this" {
  count = length(var.policy_statements) > 0 ? 1 : 0
  name = "inline"
  role = aws_iam_role.this.id
  policy = jsonencode({ Version = "2012-10-17", Statement = var.policy_statements })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "this" {
    name = "/aws/lambda/${var.name}"
    retention_in_days = var.log_retention_days  
}

resource "aws_lambda_function" "this" {
  function_name    = var.name
  role             = aws_iam_role.this.arn
  runtime          = "python3.13"
  architectures    = ["arm64"] 
  handler          = "${local.module_file}.handler"
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  timeout          = var.timeout
  memory_size      = 128

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []
    content {
      variables = var.environment
    }
  }
  depends_on = [aws_cloudwatch_log_group.this]
}