output "backend_ecr_url" {
  value = module.registry.repository_urls["pv-backend"]
}

output "ops_bucket" {
  value = module.storage.ops_bucket.name
}

output "instance_id" {
  value = module.app_server.instance_id
}

output "public_ip" {
  value = module.app_server.public_ip
}

output "deploy_role_arn" {
  value = module.github-oidc.deploy_role_arn
}

output "deploy_document_name" {
  value = module.github-oidc.deploy_document_name
}