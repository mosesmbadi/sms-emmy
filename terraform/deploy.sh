#!/bin/bash

# SMS Emmy Infrastructure Deployment Script

set -e

echo "🚀 Starting SMS Emmy Infrastructure Deployment"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install Terraform first."
    echo "Visit: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_warning "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Change to terraform directory
cd "$(dirname "$0")"

print_status "Current directory: $(pwd)"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    print_warning "Please review and modify terraform.tfvars before proceeding."
    read -p "Press Enter to continue after reviewing terraform.tfvars..."
fi

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Validate configuration
print_status "Validating Terraform configuration..."
terraform validate

if [ $? -eq 0 ]; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration validation failed"
    exit 1
fi

# Plan deployment
print_status "Creating deployment plan..."
terraform plan -out=tfplan

# Ask for confirmation
echo ""
print_warning "Review the plan above. Do you want to proceed with the deployment?"
read -p "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
    print_warning "Deployment cancelled by user."
    exit 0
fi

# Apply the plan
print_status "Applying Terraform plan..."
terraform apply tfplan

if [ $? -eq 0 ]; then
    print_success "Infrastructure deployed successfully!"
    
    # Save SSH key
    print_status "Saving SSH private key..."
    terraform output -raw ssh_private_key > sms_emmy_key.pem
    chmod 600 sms_emmy_key.pem
    
    echo ""
    print_success "=== DEPLOYMENT SUMMARY ==="
    echo "VPC ID: $(terraform output -raw vpc_id)"
    echo "Instance ID: $(terraform output -raw instance_id)"
    echo "Public IP: $(terraform output -raw instance_public_ip)"
    echo "SSH Command: $(terraform output -raw ssh_connection_command)"
    echo "Application URL: $(terraform output -raw application_url)"
    echo ""
    print_success "SSH key saved as: sms_emmy_key.pem"
    print_warning "Wait 5-10 minutes for the application to be fully deployed."
    
else
    print_error "Infrastructure deployment failed!"
    exit 1
fi
