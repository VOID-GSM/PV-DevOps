output "ops_bucket" {
  value = { 
    name = aws_s3_bucket.this["ops"].bucket, 
    arn = aws_s3_bucket.this["ops"].arn }
}

output "uploads_bucket" {
  value = { 
    name = aws_s3_bucket.this["uploads"].bucket, 
    arn = aws_s3_bucket.this["uploads"].arn }
}