#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Default Terraform directories for CloudShell
DEFAULT_TF_DATA_DIR="/tmp/tfdata"
DEFAULT_TF_PLUGIN_CACHE_DIR="/tmp/terraform-plugin-cache"

print_info "Terraform Directory Configuration for CloudShell"
echo "=================================================="
echo
print_warning "Due to CloudShell space limitations, Terraform data will be stored in /tmp"
echo

# Check current environment variables
print_status "Current Terraform environment variables:"
echo "TF_DATA_DIR: ${TF_DATA_DIR:-'not set'}"
echo "TF_PLUGIN_CACHE_DIR: ${TF_PLUGIN_CACHE_DIR:-'not set'}"
echo

# Function to set environment variables
set_terraform_dirs() {
    local tf_data_dir="$1"
    local tf_plugin_cache_dir="$2"
    
    export TF_DATA_DIR="$tf_data_dir"
    export TF_PLUGIN_CACHE_DIR="$tf_plugin_cache_dir"
    
    # Create directories if they don't exist
    mkdir -p "$TF_DATA_DIR"
    mkdir -p "$TF_PLUGIN_CACHE_DIR"
    
    print_status "Terraform directories set:"
    echo "TF_DATA_DIR=$TF_DATA_DIR"
    echo "TF_PLUGIN_CACHE_DIR=$TF_PLUGIN_CACHE_DIR"
    echo
    
    # Verify directories were created
    if [ -d "$TF_DATA_DIR" ] && [ -d "$TF_PLUGIN_CACHE_DIR" ]; then
        print_status "Directories created successfully"
        print_status "TF_DATA_DIR: $(du -sh "$TF_DATA_DIR" 2>/dev/null || echo 'empty')"
        print_status "TF_PLUGIN_CACHE_DIR: $(du -sh "$TF_PLUGIN_CACHE_DIR" 2>/dev/null || echo 'empty')"
    else
        print_error "Failed to create Terraform directories"
        exit 1
    fi
}

# Check if variables are already set correctly
if [ "$TF_DATA_DIR" = "$DEFAULT_TF_DATA_DIR" ] && [ "$TF_PLUGIN_CACHE_DIR" = "$DEFAULT_TF_PLUGIN_CACHE_DIR" ]; then
    print_status "Terraform directories are already set correctly"
    echo "TF_DATA_DIR=$TF_DATA_DIR"
    echo "TF_PLUGIN_CACHE_DIR=$TF_PLUGIN_CACHE_DIR"
else
    print_info "Setting up Terraform directories for CloudShell..."
    echo
    print_status "Recommended settings for CloudShell:"
    echo "TF_DATA_DIR=$DEFAULT_TF_DATA_DIR"
    echo "TF_PLUGIN_CACHE_DIR=$DEFAULT_TF_PLUGIN_CACHE_DIR"
    echo
    
    # Ask user for confirmation
    read -p "Use these recommended settings? (Y/n): " -r
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo
        print_info "Please enter custom paths:"
        read -p "TF_DATA_DIR (default: $DEFAULT_TF_DATA_DIR): " custom_tf_data_dir
        read -p "TF_PLUGIN_CACHE_DIR (default: $DEFAULT_TF_PLUGIN_CACHE_DIR): " custom_tf_plugin_cache_dir
        
        # Use defaults if empty
        custom_tf_data_dir=${custom_tf_data_dir:-$DEFAULT_TF_DATA_DIR}
        custom_tf_plugin_cache_dir=${custom_tf_plugin_cache_dir:-$DEFAULT_TF_PLUGIN_CACHE_DIR}
        
        set_terraform_dirs "$custom_tf_data_dir" "$custom_tf_plugin_cache_dir"
    else
        set_terraform_dirs "$DEFAULT_TF_DATA_DIR" "$DEFAULT_TF_PLUGIN_CACHE_DIR"
    fi
fi

echo
print_status "Terraform configuration complete!"
print_info "These settings will be used for all Terraform operations in this session."
echo
