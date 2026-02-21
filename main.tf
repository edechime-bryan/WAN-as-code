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

  this_vpc_id  = module.ohio-vpc.vpc_id
  peer_vpc_id  = module.tokyo-vpc.vpc_id
  this_rts_ids = concat(module.ohio-vpc.public_route_table_ids, module.ohio-vpc.private_route_table_ids)
  peer_rts_ids = concat(module.tokyo-vpc.public_route_table_ids, module.tokyo-vpc.private_route_table_ids)


  auto_accept_peering = true

  tags = {
    Name        = "ohio-tokyo-peering"
    Environment = "Test"
  }
}

module "tokyo-paris-peering" {
  source = "grem11n/vpc-peering/aws"

  providers = {
    aws.this = aws.tokyo
    aws.peer = aws.paris
  }

  this_vpc_id  = module.tokyo-vpc.vpc_id
  peer_vpc_id  = module.paris-vpc.vpc_id
  this_rts_ids = concat(module.tokyo-vpc.public_route_table_ids, module.tokyo-vpc.private_route_table_ids)
  peer_rts_ids = concat(module.paris-vpc.public_route_table_ids, module.paris-vpc.private_route_table_ids)


  auto_accept_peering = true

  tags = {
    Name        = "tokyo-paris-peering"
    Environment = "Test"
  }
}

module "ohio-paris-peering" {
  source = "grem11n/vpc-peering/aws"

  providers = {
    aws.this = aws.ohio
    aws.peer = aws.paris
  }

  this_vpc_id  = module.ohio-vpc.vpc_id
  peer_vpc_id  = module.paris-vpc.vpc_id
  this_rts_ids = concat(module.ohio-vpc.public_route_table_ids, module.ohio-vpc.private_route_table_ids)
  peer_rts_ids = concat(module.paris-vpc.public_route_table_ids, module.paris-vpc.private_route_table_ids)


  auto_accept_peering = true

  tags = {
    Name        = "ohio-paris-peering"
    Environment = "Test"
  }
}

module "ohio-ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name          = "ohio-ec2"
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  subnet_id     = module.ohio-vpc.private_subnets

  create_security_group = true
  security_group_name   = "ohio-ec2-sg"
  security_group_vpc_id = module.ohio-vpc.vpc_id

  security_group_ingress_rules = {
    allow_ping = {
      protocol    = "icmp"
      from_port   = -1
      to_port     = -1
      cidr_blocks = [module.tokyo-ec2.private_ip, module.paris-ec2.private_ip]
    }
  }

  security_group_egress_rules = {
    all = {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

module "tokyo-ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name          = "tokyo-ec2"
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  subnet_id     = module.tokyo-vpc.private_subnets

  create_security_group = true
  security_group_name   = "tokyo-ec2-sg"
  security_group_vpc_id = module.tokyo-vpc.vpc_id

  security_group_ingress_rules = {
    allow_ping = {
      protocol    = "icmp"
      from_port   = -1
      to_port     = -1
      cidr_blocks = [module.ohio-ec2.private_ip, module.paris-ec2.private_ip]
    }
  }

  security_group_egress_rules = {
    all = {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

module "paris-ec2" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name          = "paris-ec2"
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"
  subnet_id     = module.paris-vpc.private_subnets

  create_security_group = true
  security_group_name   = "paris-ec2-sg"
  security_group_vpc_id = module.paris-vpc.vpc_id

  security_group_ingress_rules = {
    allow_ping = {
      protocol    = "icmp"
      from_port   = -1
      to_port     = -1
      cidr_blocks = [module.ohio-ec2.private_ip, module.tokyo-ec2.private_ip]
    }
  }

  security_group_egress_rules = {
    all = {
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
