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

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.surf.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.surf.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name   = "surf-web-sg-sadi"
  vpc_id = aws_vpc.surf.id

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "surf" {
  key_name   = "surf-key-sadi"
  public_key = file("~/.ssh/surf-key.pub")
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.surf.key_name

  tags = { Name = "surf-web-sadi" }
}

output "web_public_ip" {
  value = aws_instance.web.public_ip
}