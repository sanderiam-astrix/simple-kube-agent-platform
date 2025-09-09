# AI Agent Lab Environment on AWS

This Terraform configuration creates a minimal, secure lab environment for running an AI agent with tools in a Kubernetes cluster on AWS. The setup is optimized for cost and simplicity while maintaining security best practices.

## Table of Contents

- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Monitoring and Logs](#monitoring-and-logs)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)
- [Security](#security)
- [Cleanup](#cleanup)
- [Support](#support)

## Architecture

- **VPC**: Single VPC with one public subnet
- **Kubernetes**: Self-managed cluster (not EKS) to support sidecar functionality
- **Master Node**: t3.medium instance running Kubernetes control plane
- **Worker Nodes**: t3.small instances (configurable count)
- **Storage**: S3 bucket for AI agent file storage with IAM role-based access
- **Networking**: Flannel CNI for pod networking
- **Security**: IAM roles, encrypted storage, security groups

## Features

- ✅ Sidecar support (required for AI agent tools)
- ✅ S3 integration with IAM roles (no static secrets)
- ✅ kubectl and helm ready
- ✅ Minimal AWS resources
- ✅ Secure by default
- ✅ Complete destroy functionality
- ✅ Cost-optimized for lab use
- ✅ Claude Code installation (multiple methods)

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0
3. kubectl
4. helm
5. SSH key pair (optional - will be generated if not provided)

### AWS CloudShell Optimization

This setup is optimized for **AWS CloudShell** usage:
- All interactions are CLI-based (no web browser required)
- Service testing uses `curl` instead of browser access
- Port forwarding runs in background for CLI testing
- All commands work within CloudShell environment
- Health check endpoints for CLI monitoring
- JSON status endpoints for programmatic access
- **Terraform data stored in /tmp** to work within CloudShell space limitations

#### CloudShell-Specific Commands

```bash
# Start CloudShell and clone the repository
git clone <your-repo-url>
cd simple-kube-agent-platform

# Set up Terraform directories for CloudShell (optional - scripts do this automatically)
./setup-terraform-dirs.sh

# Deploy the infrastructure (automatically configures Terraform directories)
./deploy.sh

# Get kubeconfig (CloudShell will handle SSH automatically)
# The actual key name will be shown in the deployment output
scp -i ~/.ssh/<key-name> ubuntu@<master-ip>:/home/ubuntu/kubeconfig ./kubeconfig
export KUBECONFIG=./kubeconfig

# Test the service (CloudShell optimized)
kubectl port-forward -n ai-agent svc/claude-code-service 8080:80 &
curl http://localhost:8080/health
curl http://localhost:8080/status
```

#### CloudShell Space Management

Due to CloudShell space limitations, Terraform data is automatically stored in `/tmp`:

```bash
# Check Terraform directory usage
du -sh /tmp/tfdata
du -sh /tmp/terraform-plugin-cache

# Clean up Terraform data if needed
rm -rf /tmp/tfdata
rm -rf /tmp/terraform-plugin-cache

# Reconfigure Terraform directories
./setup-terraform-dirs.sh
```

## Quick Start

### 5-Minute Setup

1. **Configure Variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars if needed (defaults are fine for testing)
   ```

2. **Deploy Infrastructure with Claude Code**:
   ```bash
   # Option 1: Direct installation on worker nodes (recommended for CloudShell)
   ./deploy-with-claude-code.sh
   
   # Option 2: Build Docker image and deploy (requires Docker)
   BUILD_DOCKER=true ./deploy-with-claude-code.sh
   
   # Option 3: Standard deployment (nginx placeholder)
   ./deploy.sh
   ```

3. **Get Cluster Access**:
   ```bash
   # Download kubeconfig (use the key name shown in deployment output)
   scp -i ~/.ssh/<key-name> ubuntu@<master-ip>:/home/ubuntu/kubeconfig ./kubeconfig
   
   # Set up kubectl
   export KUBECONFIG=./kubeconfig
   kubectl get nodes
   ```

4. **Verify AI Agent**:
   ```bash
   # Check AI agent status
   kubectl get pods -n ai-agent
   
   # Test the service directly
   kubectl port-forward -n ai-agent svc/claude-code-service 8080:80 &
   curl http://localhost:8080
   
   # Or test from within the cluster
   kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- curl http://claude-code-service.ai-agent.svc.cluster.local
   ```

### Alternative: Using Make

```bash
# Initialize and deploy
make init && make apply

# Get kubeconfig
make get-kubeconfig

# Check status
make status

# Cleanup
make destroy
```

## Configuration

### Key Variables

- `aws_region`: AWS region (default: us-east-2)
- `instance_type_master`: Master node instance type (default: t3.medium)
- `instance_type_worker`: Worker node instance type (default: t3.small)
- `worker_count`: Number of worker nodes (default: 1)
- `key_pair_name`: Existing SSH key pair name (leave empty to auto-generate)
- `allowed_cidr_blocks`: CIDR blocks allowed to access the cluster

### Example terraform.tfvars

```hcl
# AWS Configuration
aws_region = "us-east-2"

# Project Configuration
project_name = "ai-agent-lab"
environment  = "dev"

# Instance Configuration
instance_type_master = "t3.medium"
instance_type_worker = "t3.small"
worker_count         = 1

# Security Configuration
key_pair_name = ""  # Leave empty to auto-generate, or specify existing key pair name
allowed_cidr_blocks = ["0.0.0.0/0"]  # Restrict this to your IP range for better security

# Kubernetes Configuration
kubernetes_version = "1.28"
enable_sidecar     = true
```

## Usage

### Accessing the Cluster

```bash
# SSH to master node
ssh -i ~/.ssh/<key-name> ubuntu@<master-ip>

# SSH to worker nodes
ssh -i ~/.ssh/<key-name> ubuntu@<worker-ip>
```

### Managing the AI Agent

The AI agent is deployed in the `ai-agent` namespace:

```bash
# Check AI agent status
kubectl get pods -n ai-agent

# View AI agent logs
kubectl logs -n ai-agent deployment/claude-code-agent

# Scale the AI agent
kubectl scale deployment claude-code-agent -n ai-agent --replicas=2

# Test the AI agent service
kubectl port-forward -n ai-agent svc/claude-code-service 8080:80 &
curl http://localhost:8080
```

### Claude Code Installation

This setup provides multiple methods to install Claude Code:

#### Method 1: Direct Installation (Recommended for CloudShell)
Claude Code is installed directly on worker nodes during initialization:

```bash
# Deploy with direct Claude Code installation
./deploy-with-claude-code.sh

# Check Claude Code service status
ssh -i ~/.ssh/<key-name> ubuntu@<worker-ip> 'systemctl status claude-code'

# Test Claude Code service
ssh -i ~/.ssh/<key-name> ubuntu@<worker-ip> 'curl http://localhost:8080/health'
```

#### Method 2: Docker Image (Requires Docker)
Build and deploy Claude Code as a Docker image:

```bash
# Build and deploy with Docker
BUILD_DOCKER=true ./deploy-with-claude-code.sh

# Check pod status
kubectl get pods -n ai-agent
kubectl logs -n ai-agent deployment/claude-code-agent
```

#### Method 3: Manual Docker Build
Build the Docker image manually:

```bash
# Build Claude Code Docker image
./build-claude-code.sh

# Deploy infrastructure
terraform apply
```

### S3 Integration

The AI agent has access to the S3 bucket through IAM roles:

```bash
# List files in S3 bucket
aws s3 ls s3://<bucket-name>/

# Upload a file
aws s3 cp local-file.txt s3://<bucket-name>/

# Download a file
aws s3 cp s3://<bucket-name>/file.txt ./
```

### CLI Testing (AWS CloudShell Optimized)

```bash
# Test service health
kubectl port-forward -n ai-agent svc/claude-code-service 8080:80 &
curl http://localhost:8080/health

# Test service status (JSON response)
curl http://localhost:8080/status

# Test main endpoint
curl http://localhost:8080/

# Test from within cluster (alternative method)
kubectl run test-pod --image=curlimages/curl --rm -it --restart=Never -- \
  curl http://claude-code-service.ai-agent.svc.cluster.local/health

# Test S3 access from within the pod
kubectl exec -n ai-agent deployment/claude-code-agent -- aws s3 ls

# Check service endpoints
kubectl get endpoints -n ai-agent
```

### Available Commands

```bash
# Terraform commands
make init     # Initialize Terraform
make plan     # Plan infrastructure changes
make apply    # Deploy infrastructure
make destroy  # Destroy infrastructure
make status   # Show cluster status
make clean    # Clean up local files

# Quick start
make init && make apply
```

## Monitoring and Logs

```bash
# Check cluster health
kubectl get nodes
kubectl top nodes

# Check pod status
kubectl get pods --all-namespaces

# View system logs
kubectl logs -n kube-system <pod-name>

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check node resources
kubectl describe nodes
```

## Troubleshooting

### Common Issues

1. **Nodes not joining cluster**:
   - Check security groups allow communication between nodes
   - Verify master node is fully initialized
   - Check worker node logs: `journalctl -u kubelet`

2. **Pods not starting**:
   - Check resource limits and requests
   - Verify image availability
   - Check pod events: `kubectl describe pod <pod-name>`

3. **S3 access issues**:
   - Verify IAM role is attached to worker nodes
   - Check S3 bucket permissions
   - Verify AWS region configuration

### Useful Commands

```bash
# Get cluster info
kubectl cluster-info

# Check API server status
kubectl get --raw /healthz

# View cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check node resources
kubectl describe nodes

# Check AI agent logs
kubectl logs -n ai-agent deployment/claude-code-agent

# Check service
kubectl get svc -n ai-agent

# Check persistent volume
kubectl get pvc -n ai-agent

# Test S3 access from pod
kubectl exec -n ai-agent deployment/claude-code-agent -- aws s3 ls

# Test service connectivity (CLI method)
kubectl port-forward -n ai-agent svc/claude-code-service 8080:80 &
curl -v http://localhost:8080/health
curl -v http://localhost:8080/status

# Check service logs
kubectl logs -n ai-agent deployment/claude-code-agent --tail=50

# Test from within cluster
kubectl run debug-pod --image=curlimages/curl --rm -it --restart=Never -- \
  sh -c "curl http://claude-code-service.ai-agent.svc.cluster.local/health && curl http://claude-code-service.ai-agent.svc.cluster.local/status"

# Claude Code specific troubleshooting
# Check Claude Code service on worker nodes (direct installation)
ssh -i ~/.ssh/<key-name> ubuntu@<worker-ip> 'systemctl status claude-code'
ssh -i ~/.ssh/<key-name> ubuntu@<worker-ip> 'journalctl -u claude-code -f'

# Check Claude Code logs
ssh -i ~/.ssh/<key-name> ubuntu@<worker-ip> 'curl -v http://localhost:8080/status'

# Test Claude Code installation
ssh -i ~/.ssh/<key-name> ubuntu@<worker-ip> 'which claude-code || echo "Claude Code not found"'

# Terraform directory issues (CloudShell)
# Check if Terraform directories are set correctly
echo "TF_DATA_DIR: $TF_DATA_DIR"
echo "TF_PLUGIN_CACHE_DIR: $TF_PLUGIN_CACHE_DIR"

# Reconfigure Terraform directories
./setup-terraform-dirs.sh

# Check disk space
df -h /tmp
du -sh /tmp/tfdata /tmp/terraform-plugin-cache 2>/dev/null || echo "Terraform directories not found"
```

## Cost Optimization

This setup is optimized for minimal cost:

- Uses t3 instances (burstable performance)
- Single AZ deployment
- Minimal storage (20GB per node)
- No load balancers (uses NodePort)
- No NAT gateways

### Cost Estimate

- **t3.medium** (master): ~$30/month
- **t3.small** (worker): ~$15/month each
- **EBS Storage**: ~$2/month per 20GB
- **S3**: ~$1/month for typical usage
- **Total**: ~$50-100/month depending on usage

## Security

### Security Features

- All storage encrypted at rest
- IAM roles instead of static credentials
- Security groups with least privilege
- S3 bucket with public access blocked
- Encrypted EBS volumes

### Security Considerations

- Change default passwords and keys
- Restrict SSH access to your IP range
- Regularly update Kubernetes and system packages
- Monitor AWS CloudTrail for API access
- Use AWS Config for compliance monitoring

### Security Groups

- **Master**: SSH (22), Kubernetes API (6443), etcd (2379-2380), kubelet (10250)
- **Worker**: SSH (22), kubelet (10250), NodePort (30000-32767)
- **Load Balancer**: HTTP (80), HTTPS (443)

## Cleanup

**IMPORTANT**: Always run destroy to avoid AWS charges:

```bash
# Using script
./destroy.sh

# Using make
make destroy

# Using terraform directly
terraform destroy
```

This will remove all AWS resources created by this configuration.

### Local Cleanup

```bash
# Clean up local files
make clean

# Full cleanup (including destroy)
make full-clean
```

## Support

For issues and questions:

1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Check Kubernetes events and logs
4. Verify Terraform state and outputs
5. Check the Makefile for available commands

### File Structure

```
.
├── main.tf                          # Main Terraform configuration
├── variables.tf                     # Variable definitions
├── vpc.tf                          # VPC and networking
├── security.tf                     # Security groups
├── iam.tf                          # IAM roles and policies
├── s3.tf                           # S3 bucket configuration
├── ec2.tf                          # EC2 instances
├── outputs.tf                      # Output values
├── versions.tf                     # Provider versions
├── terraform.tfvars.example        # Example variables
├── ai-agent-deployment.yaml        # AI agent deployment
├── Dockerfile.claude-code          # Claude Code Docker image
├── build-claude-code.sh            # Docker build script
├── deploy-with-claude-code.sh      # Enhanced deployment script
├── setup-terraform-dirs.sh         # Terraform directory setup for CloudShell
├── scripts/
│   ├── master-init.sh              # Master node initialization
│   ├── worker-init.sh              # Worker node initialization
│   ├── install-claude-code.sh      # Claude Code installation script
│   └── terraform-setup.sh          # Terraform directory configuration
├── deploy.sh                       # Standard deployment script
├── destroy.sh                      # Cleanup script
├── Makefile                        # Management commands
└── README.md                       # This documentation
```

## Next Steps

1. **Customize AI Agent**: Modify `ai-agent-deployment.yaml`
2. **Add More Tools**: Deploy additional sidecar containers
3. **Scale Workers**: Increase `worker_count` in `terraform.tfvars`
4. **Monitor**: Set up logging and monitoring
5. **Secure**: Restrict SSH access to your IP range