terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.23" }
  }

  backend "s3" {
    bucket       = "pv-tfstate-959589243103"
    key          = "pv/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-northeast-2"
  default_tags {
    tags = {
      Project   = "pv"
      ManagedBy = "terraform"
    }
  }
}