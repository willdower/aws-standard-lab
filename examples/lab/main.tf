terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      Project   = "aws-standard-lab"
      ManagedBy = "terraform"
    }
  }
}

module "lab" {
  source = "../.."

  name                = var.name
  admin_ipv4_cidr     = var.admin_ipv4_cidr
  admin_ipv6_cidr     = var.admin_ipv6_cidr
  ssh_public_key_path = var.ssh_public_key_path
  ssh_username        = var.ssh_username
  ec2_subnets         = var.ec2_subnets
}

output "lab" {
  value = {
    vpc_id            = module.lab.vpc_id
    public_subnet_ids = module.lab.public_subnet_ids
    instances         = module.lab.instances
  }
}
