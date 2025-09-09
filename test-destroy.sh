#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_status "Testing destroy script..."

# Set up Terraform directories
export TF_DATA_DIR="/tmp/tfdata"
export TF_PLUGIN_CACHE_DIR="/tmp/terraform-plugin-cache"
mkdir -p "$TF_DATA_DIR"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

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

print_status "Running terraform plan -destroy (dry run)..."
if terraform plan -destroy; then
    print_status "✓ terraform plan -destroy succeeded"
else
    print_error "✗ terraform plan -destroy failed"
    exit 1
fi

print_status "Destroy script test completed successfully!"
print_warning "This was just a test - no resources were actually destroyed."
