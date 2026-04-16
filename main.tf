terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # THIS IS THE PERMANENT MEMORY BANK
  backend "s3" {
    bucket         = "enterprise-k8s-tfstate-shuja" # <-- REPLACE THIS BEFORE SAVING
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "enterprise-k8s-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. Build a Fresh, Isolated Private Network (VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "enterprise-k8s-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# 2. Build the Kubernetes Cluster (EKS)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "enterprise-k8s-cluster"
  cluster_version = "1.30"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  enable_cluster_creator_admin_permissions = true

  # --- THE NEW FIREWALL RULES ---
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  # ------------------------------

  # 3. Create the Worker Node Group
  eks_managed_node_groups = {
    enterprise_nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2 
      instance_types = ["t3.medium"] 
    }
  }
}