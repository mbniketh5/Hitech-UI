resource "aws_instance" "web" {
  ami           = "ami-0dd60a46ecc6eac16"
  instance_type = var.instance_type

  tags = {
    Name = var.instance_name
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_name             = "hitech-vpc"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_1_cidr = "10.0.1.0/24"
  public_subnet_2_cidr = "10.0.2.0/24"
}

module "security_group" {
  source = "./modules/security-group"

  vpc_id = module.vpc.vpc_id
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = "hitech-ui-repo"
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = "hitech-eks"
  node_group_name = "hitech-workers"

  subnet_ids = [
    module.vpc.subnet_1_id,
    module.vpc.subnet_2_id
  ]
}
