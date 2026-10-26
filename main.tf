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
  infra_repo           = "VOID-GSM@253180703/PV-DevOps@1409495652"
  state_bucket         = "pv-tfstate-959589243103"
}

module "cloudfront" {
  source            = "./modules/cloudfront"
  name              = local.name
  api_origin_domain = module.ec2.public_dns
}

module "backup" {
  source          = "./modules/backup"
  name            = local.name
  alarm_topic_arn = module.sns.topic_arn
}

# ---------- 알림 ----------

module "sns" {
  source                   = "./modules/sns"
  name                     = local.name
  subscriber_function_arn  = module.discord_notifier.function_arn
  subscriber_function_name = module.discord_notifier.function_name
}

module "discord_notifier" {
  source      = "./modules/lambda"
  name        = "${local.name}-discord-notifier"
  source_file = "${path.root}/functions/discord_notifier.py"
  environment = {
    WEBHOOK_PARAM = "/${local.project}/alerts/DISCORD_WEBHOOK_URL"
  }
  policy_statements = [{
    Effect   = "Allow"
    Action   = "ssm:GetParameter"
    Resource = "arn:aws:ssm:${local.region}:959589243103:parameter/${local.project}/alerts/DISCORD_WEBHOOK_URL"
  }]
}

module "health_check" {
  source      = "./modules/lambda"
  name        = "${local.name}-health-check"
  source_file = "${path.root}/functions/health_check.py"
  timeout     = 30
  policy_statements = [{
    Effect    = "Allow"
    Action    = "cloudwatch:PutMetricData"
    Resource  = "*"
    Condition = { StringEquals = { "cloudwatch:namespace" = "PV/HealthCheck" } }
  }]
}

module "cloudwatch" {
  source                     = "./modules/cloudwatch"
  name                       = local.name
  instance_id                = module.ec2.instance_id
  alarm_topic_arn            = module.sns.topic_arn
  health_check_function_arn  = module.health_check.function_arn
  health_check_function_name = module.health_check.function_name
  health_check_targets = {
    api = "https://${module.cloudfront.domain_name}/api/swagger-ui/index.html"
    web = "https://${module.cloudfront.domain_name}/"
  }
}

module "budgets" {
  source          = "./modules/budgets"
  name            = local.name
  alarm_topic_arn = module.sns.topic_arn
}