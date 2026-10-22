locals {
  project = "pv"
  region = "ap-northeast-2"
  name = local.project
  instance_type = "t4g.small"

  github_repos = [
    "VOID-GSM/PV-DevOps",
    "VOID-GSM/PV-Server",
    "VOID-GSM/PV-Web",
  ]
}

module "network" {
  source = "./modules/network"
  name = local.name
  availability_zone = "${local.region}a"
}

module "registry" {
  source = "./modules/registry"
  repositories = ["${local.project}-backend"]
}

module "storage" {
  source = "./modules/storage"
  name = local.name
}