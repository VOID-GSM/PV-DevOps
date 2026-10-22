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