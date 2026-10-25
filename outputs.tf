output "backend_ecr_url" {
  value = module.ecr.repository_urls["pv-backend"]
}

output "ops_bucket" {
  value = module.s3.ops_bucket.name
}

output "instance_id" {
  value = module.ec2.instance_id
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "deploy_role_arn" {
  value = module.iam.deploy_role_arn
}

output "deploy_document_name" {
  value = module.iam.deploy_document_name
}

output "web_url" {
  value = "https://${module.cloudfront.domain_name}"
}

output "swagger_url" {
  value = "https://${module.cloudfront.domain_name}/api/swagger-ui/index.html"
}

output "web_bucket" {
  value = module.cloudfront.bucket_name
}

output "cf_distribution_id" {
  value = module.cloudfront.distribution_id
}

output "backup_vault" {
  value = module.backup.vault_name
}

output "backup_role_arn" {
  value = module.backup.role_arn
}

output "alarm_topic_arn" {
  value = module.sns.topic_arn
}

output "terraform_plan_role_arn" {
  value = module.iam.terraform_plan_role_arn
}