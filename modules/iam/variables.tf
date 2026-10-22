variable "name" { type = string }
variable "github_repos" { type = list(string) }
variable "ecr_repository_arns" { type = list(string) }
variable "ops_bucket" { type = string }
variable "instance_arn" { type = string }
variable "deploy_branches" { type = list(string) }
variable "web_bucket_arn" { type = string }
variable "web_distribution_arn" { type = string }