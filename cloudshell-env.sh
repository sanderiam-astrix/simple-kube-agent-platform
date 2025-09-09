#!/bin/bash
# CloudShell Environment Setup for AI Agent Lab
# Source this file to set up the environment: source cloudshell-env.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_info "Setting up CloudShell environment for AI Agent Lab..."

# Set Terraform directories for CloudShell
export TF_DATA_DIR="/tmp/tfdata"
export TF_PLUGIN_CACHE_DIR="/tmp/terraform-plugin-cache"

# Create directories if they don't exist
mkdir -p "$TF_DATA_DIR"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

print_status "Environment variables set:"
echo "TF_DATA_DIR=$TF_DATA_DIR"
echo "TF_PLUGIN_CACHE_DIR=$TF_PLUGIN_CACHE_DIR"

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    print_status "Warning: main.tf not found. Make sure you're in the project directory."
fi

print_status "CloudShell environment ready!"
print_info "You can now run: ./deploy.sh or ./deploy-with-claude-code.sh"
