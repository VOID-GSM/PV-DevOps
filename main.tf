locals {
  project       = "pv"
  region        = "ap-northeast-2"
  name          = local.project
  instance_type = "t4g.small"

  github_repos = [
    "VOID-GSM/PV-DevOps",
    "VOID-GSM/PV-Server",
    "VOID-GSM/PV-Web",
  ]
}

module "network" {
  source            = "./modules/network"
  name              = local.name
  availability_zone = "${local.region}a"
}

module "registry" {
  source       = "./modules/registry"
  repositories = ["${local.project}-backend"]
}

module "storage" {
  source = "./modules/storage"
  name   = local.name
}

module "app_server" {
  source            = "./modules/app-server"
  name              = local.name
  instance_type     = local.instance_type
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.web_security_group_id
  registry_url      = module.registry.registry_url
  ops_bucket        = module.storage.ops_bucket.name
  uploads_bucket    = module.storage.uploads_bucket.name
  ssm_path          = "/${local.project}/"
}

module "github-oidc" {
  source              = "./modules/github-oidc"
  name                = local.name
  github_repos        = local.github_repos
  ecr_repository_arns = module.registry.repository_arns
  ops_bucket          = module.storage.ops_bucket.name
  instance_arn        = module.app_server.instance_arn
  deploy_branches = ["main", "develop"]
}