#!/bin/bash

# SMS Emmy Infrastructure Destruction Script

set -e

echo "🗑️  SMS Emmy Infrastructure Cleanup"
echo "================================="

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

# Change to terraform directory
cd "$(dirname "$0")"

print_warning "This will destroy ALL infrastructure created by Terraform."
print_warning "This action is IRREVERSIBLE!"

# Show what will be destroyed
print_status "Showing resources that will be destroyed..."
terraform plan -destroy

echo ""
print_error "Are you absolutely sure you want to destroy all resources?"
print_warning "Type 'DELETE' (in caps) to confirm destruction:"
read -p "> " confirm

if [ "$confirm" != "DELETE" ]; then
    print_success "Destruction cancelled. Your infrastructure is safe."
    exit 0
fi

print_status "Destroying infrastructure..."
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    print_success "Infrastructure destroyed successfully!"
    
    # Clean up local files
    print_status "Cleaning up local files..."
    rm -f sms_emmy_key.pem
    rm -f tfplan
    rm -f terraform.tfstate.backup
    
    print_success "Cleanup completed!"
else
    print_error "Failed to destroy some resources. Please check manually."
    exit 1
fi
