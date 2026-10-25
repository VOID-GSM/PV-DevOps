variable "name" { type = string }
variable "github_repos" { type = list(string) }
variable "ecr_repository_arns" { type = list(string) }
variable "ops_bucket" { type = string }
variable "instance_arn" { type = string }
variable "deploy_branches" { type = list(string) }
variable "web_bucket_arn" { type = string }
variable "web_distribution_arn" { type = string }
variable "infra_repo" {
  description = "plan을 실행할 레포 (OIDC sub 형식: ORG@id/REPO@id)"
  type        = string
}

variable "state_bucket" {
  description = "Terraform state가 저장된 S3 버킷 이름"
  type        = string
}