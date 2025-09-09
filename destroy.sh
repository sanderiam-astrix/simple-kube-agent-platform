#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Set up Terraform directories for CloudShell (non-interactive)
export TF_DATA_DIR="/tmp/tfdata"
export TF_PLUGIN_CACHE_DIR="/tmp/terraform-plugin-cache"
mkdir -p "$TF_DATA_DIR"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
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
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    print_error "main.tf not found. Please run this script from the project directory."
    exit 1
fi

# Check if terraform state exists
if [ ! -f ".terraform/terraform.tfstate" ] && [ ! -f "terraform.tfstate" ]; then
    print_error "No Terraform state found. Nothing to destroy."
    exit 1
fi

print_warning "This will DESTROY all AWS resources created by this Terraform configuration."
print_warning "This action cannot be undone!"

# Show what will be destroyed
print_status "Planning destruction..."
if ! terraform plan -destroy; then
    print_error "Terraform plan failed. Please check the output above."
    exit 1
fi

echo
read -p "Are you sure you want to destroy all resources? Type 'yes' to confirm: " -r
if [[ ! $REPLY == "yes" ]]; then
    print_warning "Destruction cancelled."
    exit 0
fi

print_status "Destroying infrastructure..."
terraform destroy -auto-approve

print_status "Cleanup completed!"
print_status "All AWS resources have been destroyed."

# Clean up local files
print_status "Cleaning up local files..."
rm -f kubeconfig
rm -f tfplan
rm -f .terraform.lock.hcl

print_status "Local cleanup completed!"
