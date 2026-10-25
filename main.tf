locals {
  project       = "pv"
  region        = "ap-northeast-2"
  name          = local.project
  instance_type = "t4g.small"

  github_repos = [
    "VOID-GSM@253180703/PV-Server@1407002025",
    "VOID-GSM@253180703/PV-DevOps@1409495652",
    "VOID-GSM@253180703/PV-Web@1407001594",
  ]
}

module "vpc" {
  source            = "./modules/vpc"
  name              = local.name
  availability_zone = "${local.region}a"
}

module "ecr" {
  source       = "./modules/ecr"
  repositories = ["${local.project}-backend"]
}

module "s3" {
  source = "./modules/s3"
  name   = local.name
}

module "ec2" {
  source            = "./modules/ec2"
  name              = local.name
  instance_type     = local.instance_type
  subnet_id         = module.vpc.public_subnet_id
  security_group_id = module.vpc.web_security_group_id
  registry_url      = module.ecr.registry_url
  ops_bucket        = module.s3.ops_bucket.name
  uploads_bucket    = module.s3.uploads_bucket.name
  ssm_path          = "/${local.project}/"
}

module "iam" {
  source               = "./modules/iam"
  name                 = local.name
  github_repos         = local.github_repos
  deploy_branches      = ["main", "develop"]
  ecr_repository_arns  = module.ecr.repository_arns
  ops_bucket           = module.s3.ops_bucket.name
  instance_arn         = module.ec2.instance_arn
  web_bucket_arn       = module.cloudfront.bucket_arn
  web_distribution_arn = module.cloudfront.distribution_arn
}

module "cloudfront" {
  source            = "./modules/cloudfront"
  name              = local.name
  api_origin_domain = module.ec2.public_dns
}

module "backup" {
  source = "./modules/backup"
  name   = local.name
}

module "sns" {
  source                   = "./modules/sns"
  name                     = local.name
  subscriber_function_arn  = module.discord_notifier.function_arn
  subscriber_function_name = module.discord_notifier.function_name
}

moved {
  from = module.network
  to   = module.vpc
}

moved {
  from = module.registry
  to   = module.ecr
}

moved {
  from = module.storage
  to   = module.s3
}

moved {
  from = module.app_server
  to   = module.ec2
}

moved {
  from = module.github-oidc
  to   = module.iam
}