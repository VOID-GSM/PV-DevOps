output "backend_ecr_url" {
  value = module.registry.repository_urls["pv-backend"]
}

output "ops_bucket" {
  value = module.storage.ops_bucket.name
}