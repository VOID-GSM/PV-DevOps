data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "this" {
  for_each = toset(["ops", "uploads"])
  bucket   = "${var.name}-${each.key}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_policy     = true
  block_public_acls       = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.this["uploads"].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket     = aws_s3_bucket.this["uploads"].id
  depends_on = [aws_s3_bucket_versioning.uploads]
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ops" {
  bucket = aws_s3_bucket.this["ops"].id
  rule {
    id     = "expire-db-backups"
    status = "Enabled"
    filter {
      prefix = "backups/"
    }
    expiration {
      days = var.backup_retention_days
    }
  }
}