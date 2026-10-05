terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "surf-tfstate-sadi"
    key            = "ericeira/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "surf-tflock-sadi"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32"
}

resource "aws_vpc" "surf" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "surf-vpc-sadi" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.surf.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "surf-public-a-sadi" }
}