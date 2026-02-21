terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.32"
    }
  }

  required_version = ">= 1.2"
}


provider "aws" {
  alias  = "ohio"
  region = "us-east-2"
}

provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

provider "aws" {
  alias  = "paris"
  region = "eu-west-3"
}

module "ohio-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "ohio-vpc"
  cidr = "10.11.53.0/24"

  azs             = ["us-east-2a"]
  private_subnets = ["10.0.1.0/26"]
  public_subnets  = ["10.0.101.128/26"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "tokyo-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "tokyo-vpc"
  cidr = "192.168.16.0/24"

  azs             = ["ap-northeast-1a"]
  private_subnets = ["192.168.16.0/26"]
  public_subnets  = ["192.168.16.128/26"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "paris-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "paris-vpc"
  cidr = "172.21.0.0/16"

  azs             = ["eu-west-3a"]
  private_subnets = ["172.21.0.0/17"]
  public_subnets  = ["172.21.128.0/17"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ohio-tokyo-peering" {
  source = "grem11n/vpc-peering/aws"

  providers = {
    aws.this = aws.ohio
    aws.peer = aws.tokyo
  }

  this_vpc_id = var.ohio_vpc_id
  peer_vpc_id = var.tokyo_vpc_id

  auto_accept_peering = true

  tags = {
    Name        = "ohio-tokyo-peering"
    Environment = "Test"
  }
}
