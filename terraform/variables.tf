# Variables for SMS Emmy Application Infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project - used as prefix for resources"
  type        = string
  default     = "sms-emmy"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "admin_username" {
  description = "Admin username for the EC2 instance"
  type        = string
  default     = "ubuntu"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "development"
    Project     = "sms-emmy"
    Owner       = "devops-team"
    CreatedBy   = "terraform"
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to the EC2 instance"
  type        = string
  default     = "0.0.0.0/0" # In production, restrict this to your IP
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}
