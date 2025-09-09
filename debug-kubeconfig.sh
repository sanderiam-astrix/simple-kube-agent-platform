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

# Get master IP
MASTER_IP=$(terraform output -raw k8s_master_public_ip 2>/dev/null || echo "")
KEY_NAME=$(terraform output -raw ssh_key_name 2>/dev/null || echo "")

if [ -z "$MASTER_IP" ] || [ -z "$KEY_NAME" ]; then
    print_error "Could not get master IP or key name. Make sure Terraform has been applied."
    exit 1
fi

print_status "Debugging kubeconfig on master node..."
print_status "Master IP: $MASTER_IP"
print_status "Key Name: $KEY_NAME"

# Check if key file exists
if [ ! -f "~/.ssh/${KEY_NAME}.pem" ]; then
    print_warning "SSH key not found in ~/.ssh/${KEY_NAME}.pem"
    print_status "Checking for key in current directory..."
    if [ -f "${KEY_NAME}.pem" ]; then
        print_status "Found key in current directory, copying to ~/.ssh/"
        cp "${KEY_NAME}.pem" ~/.ssh/
        chmod 600 ~/.ssh/"${KEY_NAME}.pem"
    else
        print_error "SSH key not found anywhere!"
        exit 1
    fi
fi

# SSH to master and check kubeconfig
print_status "Checking kubeconfig on master node..."

ssh -i ~/.ssh/"${KEY_NAME}.pem" ubuntu@$MASTER_IP << 'EOF'
echo "=== Master Node Debug Info ==="
echo "Current user: $(whoami)"
echo "Home directory: $HOME"
echo "Current directory: $(pwd)"
echo

echo "=== Checking kubeconfig file ==="
if [ -f "/home/ubuntu/kubeconfig" ]; then
    echo "✓ kubeconfig exists"
    echo "File size: $(wc -c < /home/ubuntu/kubeconfig) bytes"
    echo "File permissions: $(ls -la /home/ubuntu/kubeconfig)"
    echo "File owner: $(stat -c '%U:%G' /home/ubuntu/kubeconfig)"
    echo
    echo "=== kubeconfig content (first 10 lines) ==="
    head -10 /home/ubuntu/kubeconfig
else
    echo "✗ kubeconfig does NOT exist"
    echo
    echo "=== Checking for admin.conf ==="
    if [ -f "/etc/kubernetes/admin.conf" ]; then
        echo "✓ admin.conf exists"
        echo "File size: $(wc -c < /etc/kubernetes/admin.conf) bytes"
    else
        echo "✗ admin.conf does NOT exist"
    fi
fi

echo
echo "=== Kubernetes cluster status ==="
if command -v kubectl &> /dev/null; then
    echo "kubectl is available"
    kubectl get nodes 2>/dev/null || echo "Failed to get nodes"
else
    echo "kubectl is NOT available"
fi

echo
echo "=== Setup completion status ==="
if [ -f "/var/log/k8s-setup-complete" ]; then
    echo "✓ Kubernetes setup completed"
else
    echo "✗ Kubernetes setup NOT completed"
fi
EOF

print_status "Debug completed!"
