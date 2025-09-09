#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Source Terraform setup
source "$(dirname "$0")/scripts/terraform-setup.sh"

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

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    print_warning "Please edit terraform.tfvars with your configuration before proceeding."
    exit 1
fi

print_status "Starting deployment of AI Agent Lab Environment..."

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Plan deployment
print_status "Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled."
    exit 0
fi

# Apply deployment
print_status "Deploying infrastructure..."
terraform apply tfplan

# Get outputs
print_status "Deployment completed! Getting connection information..."

MASTER_IP=$(terraform output -raw k8s_master_public_ip)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

# Get the SSH key name
KEY_NAME=$(terraform output -raw ssh_key_name)

# Copy the private key to ~/.ssh/ if it was auto-generated
if [ -f "${KEY_NAME}.pem" ]; then
    print_status "Copying SSH private key to ~/.ssh/"
    cp "${KEY_NAME}.pem" ~/.ssh/
    chmod 600 ~/.ssh/"${KEY_NAME}.pem"
    print_status "SSH key copied to ~/.ssh/${KEY_NAME}.pem"
fi

print_status "Deployment Summary:"
echo "===================="
echo "Master Node IP: $MASTER_IP"
echo "S3 Bucket: $S3_BUCKET"
echo "SSH Key: $KEY_NAME"
echo "Region: us-east-2"
echo

print_status "Next steps:"
echo "1. Download kubeconfig:"
echo "   scp -i ~/.ssh/$KEY_NAME.pem ubuntu@$MASTER_IP:/home/ubuntu/kubeconfig ./kubeconfig"
echo
echo "2. Set up kubectl:"
echo "   export KUBECONFIG=./kubeconfig"
echo "   kubectl get nodes"
echo
echo "3. Check AI agent status:"
echo "   kubectl get pods -n ai-agent"
echo
echo "4. Test AI agent service:"
echo "   kubectl port-forward -n ai-agent svc/claude-code-service 8080:80 &"
echo "   curl http://localhost:8080"
echo

print_status "To destroy the environment when done:"
echo "terraform destroy"

# Clean up plan file
rm -f tfplan

print_status "Deployment script completed!"
