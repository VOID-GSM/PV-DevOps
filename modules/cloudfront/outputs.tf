output "bucket_name" { value = aws_s3_bucket.web.bucket }
output "bucket_arn" { value = aws_s3_bucket.web.arn }
output "distribution_id" { value = aws_cloudfront_distribution.this.id }
output "distribution_arn" { value = aws_cloudfront_distribution.this.arn }
output "domain_name" { value = aws_cloudfront_distribution.this.domain_name }