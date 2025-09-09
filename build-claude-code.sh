#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Configuration
AWS_REGION=${AWS_REGION:-us-east-2}
PROJECT_NAME=${PROJECT_NAME:-ai-agent-lab}
ENVIRONMENT=${ENVIRONMENT:-dev}
IMAGE_TAG=${IMAGE_TAG:-latest}

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPOSITORY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-${ENVIRONMENT}-claude-code"

print_status "Building Claude Code Docker image..."
print_status "AWS Account: $ACCOUNT_ID"
print_status "AWS Region: $AWS_REGION"
print_status "ECR Repository: $ECR_REPOSITORY"
print_status "Image Tag: $IMAGE_TAG"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create ECR repository if it doesn't exist
print_status "Creating ECR repository if it doesn't exist..."
aws ecr describe-repositories --repository-names "${PROJECT_NAME}-${ENVIRONMENT}-claude-code" --region $AWS_REGION >/dev/null 2>&1 || \
aws ecr create-repository \
    --repository-name "${PROJECT_NAME}-${ENVIRONMENT}-claude-code" \
    --region $AWS_REGION \
    --image-scanning-configuration scanOnPush=true

# Get ECR login token
print_status "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY

# Build the Docker image
print_status "Building Docker image..."
docker build -f Dockerfile.claude-code -t claude-code:$IMAGE_TAG .

# Tag the image for ECR
print_status "Tagging image for ECR..."
docker tag claude-code:$IMAGE_TAG $ECR_REPOSITORY:$IMAGE_TAG

# Push the image to ECR
print_status "Pushing image to ECR..."
docker push $ECR_REPOSITORY:$IMAGE_TAG

# Clean up local image
print_status "Cleaning up local image..."
docker rmi claude-code:$IMAGE_TAG $ECR_REPOSITORY:$IMAGE_TAG

print_status "Claude Code image built and pushed successfully!"
print_status "Image URI: $ECR_REPOSITORY:$IMAGE_TAG"

# Update the deployment YAML with the new image
print_status "Updating deployment configuration..."
sed -i.bak "s|image: nginx:alpine|image: $ECR_REPOSITORY:$IMAGE_TAG|g" ai-agent-deployment.yaml

print_status "Deployment configuration updated!"
print_status "You can now deploy with: kubectl apply -f ai-agent-deployment.yaml"
