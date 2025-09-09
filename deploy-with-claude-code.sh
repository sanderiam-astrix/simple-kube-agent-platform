#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Source Terraform setup
source "$(dirname "$0")/scripts/terraform-setup.sh"

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Claude Code AI Agent Lab - Enhanced Deployment"
echo "=================================================="

# Check if we should build Docker image or use direct installation
BUILD_DOCKER=${BUILD_DOCKER:-false}

if [ "$BUILD_DOCKER" = "true" ]; then
    print_status "Building Claude Code Docker image..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not available. Please install Docker or set BUILD_DOCKER=false"
        exit 1
    fi
    
    # Build and push Docker image
    ./build-claude-code.sh
    
    print_status "Docker image built and pushed. Deploying infrastructure..."
else
    print_status "Using direct Claude Code installation on worker nodes..."
    print_status "Claude Code will be installed during worker node initialization."
fi

# Deploy infrastructure
print_status "Deploying infrastructure..."
terraform init
terraform plan -out=tfplan
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
echo "Claude Code: $(if [ "$BUILD_DOCKER" = "true" ]; then echo "Docker Image"; else echo "Direct Installation"; fi)"
echo

print_status "Next steps:"
echo "1. Wait for cluster to finish initializing (up to 5 minutes), then download kubeconfig:"
echo "   scp -i ~/.ssh/$KEY_NAME.pem ubuntu@$MASTER_IP:/home/ubuntu/kubeconfig ./kubeconfig"
echo "   # Alternative (if certificate issues): scp -i ~/.ssh/$KEY_NAME.pem ubuntu@$MASTER_IP:/home/ubuntu/kubeconfig-private ./kubeconfig"
echo
echo "2. Set up kubectl:"
echo "   export KUBECONFIG=./kubeconfig"
echo "   kubectl get nodes"
echo
echo "3. Check Claude Code status:"
if [ "$BUILD_DOCKER" = "true" ]; then
    echo "   kubectl get pods -n ai-agent"
    echo "   kubectl logs -n ai-agent deployment/claude-code-agent"
else
    echo "   # Check Claude Code service on worker nodes"
    echo "   ssh -i ~/.ssh/$KEY_NAME ubuntu@$MASTER_IP 'systemctl status claude-code'"
    echo "   # Test Claude Code service"
    echo "   ssh -i ~/.ssh/$KEY_NAME ubuntu@$MASTER_IP 'curl http://localhost:8080/health'"
fi
echo
echo "4. Test the service:"
echo "   kubectl port-forward -n ai-agent svc/claude-code-service 8080:80 &"
echo "   curl http://localhost:8080/health"
echo "   curl http://localhost:8080/status"
echo

print_status "To destroy the environment when done:"
echo "terraform destroy"

# Clean up plan file
rm -f tfplan

print_status "Deployment script completed!"
