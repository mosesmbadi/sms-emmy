# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create VPC
resource "aws_vpc" "sms_emmy_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Create Internet Gateway
resource "aws_internet_gateway" "sms_emmy_igw" {
  vpc_id = aws_vpc.sms_emmy_vpc.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# Create public subnet
resource "aws_subnet" "sms_emmy_public_subnet" {
  vpc_id                  = aws_vpc.sms_emmy_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-subnet"
  })
}

# Create route table for public subnet
resource "aws_route_table" "sms_emmy_public_rt" {
  vpc_id = aws_vpc.sms_emmy_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sms_emmy_igw.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

# Associate route table with public subnet
resource "aws_route_table_association" "sms_emmy_public_rta" {
  subnet_id      = aws_subnet.sms_emmy_public_subnet.id
  route_table_id = aws_route_table.sms_emmy_public_rt.id
}

# Create Security Group
resource "aws_security_group" "sms_emmy_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for SMS Emmy application"
  vpc_id      = aws_vpc.sms_emmy_vpc.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Flask application port
  ingress {
    description = "Flask App"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

# Generate SSH key pair
resource "tls_private_key" "sms_emmy_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair
resource "aws_key_pair" "sms_emmy_key_pair" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.sms_emmy_ssh.public_key_openssh

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-key"
  })
}

# Get the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Allocate Elastic IP (Static IP)
resource "aws_eip" "sms_emmy_eip" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eip"
  })
}

# Create EC2 Instance
resource "aws_instance" "sms_emmy_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.sms_emmy_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.sms_emmy_sg.id]
  subnet_id              = aws_subnet.sms_emmy_public_subnet.id

  # User data script for initial setup
  user_data = base64encode(file("${path.module}/cloud-init.yml"))

  # Root volume configuration
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true

    tags = merge(var.common_tags, {
      Name = "${var.project_name}-root-volume"
    })
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-instance"
  })
}

# Associate Elastic IP with EC2 instance
resource "aws_eip_association" "sms_emmy_eip_assoc" {
  instance_id   = aws_instance.sms_emmy_instance.id
  allocation_id = aws_eip.sms_emmy_eip.id
}
