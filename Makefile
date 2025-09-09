.PHONY: help init plan apply destroy status clean

# Default target
help:
	@echo "AI Agent Lab Environment - Available Commands:"
	@echo ""
	@echo "  make init     - Initialize Terraform"
	@echo "  make plan     - Plan infrastructure changes"
	@echo "  make apply    - Deploy infrastructure"
	@echo "  make destroy  - Destroy infrastructure"
	@echo "  make status   - Show cluster status"
	@echo "  make clean    - Clean up local files"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Quick Start:"
	@echo "  make init && make apply"

# Initialize Terraform
init:
	terraform init

# Plan infrastructure
plan:
	terraform plan

# Apply infrastructure
apply:
	terraform apply -auto-approve

# Destroy infrastructure
destroy:
	terraform destroy -auto-approve

# Show cluster status
status:
	@echo "=== Terraform Outputs ==="
	@terraform output
	@echo ""
	@echo "=== Cluster Status ==="
	@if [ -f kubeconfig ]; then \
		export KUBECONFIG=./kubeconfig && \
		kubectl get nodes && \
		echo "" && \
		kubectl get pods -n ai-agent; \
	else \
		echo "kubeconfig not found. Run 'make get-kubeconfig' first."; \
	fi

# Get kubeconfig from master node
get-kubeconfig:
	@MASTER_IP=$$(terraform output -raw k8s_master_public_ip 2>/dev/null || echo ""); \
	if [ -z "$$MASTER_IP" ]; then \
		echo "Error: Could not get master IP. Is the infrastructure deployed?"; \
		exit 1; \
	fi; \
	KEY_NAME=$$(terraform output -raw key_pair_name 2>/dev/null || echo "ai-agent-lab-dev-k8s-key"); \
	echo "Downloading kubeconfig from master node ($$MASTER_IP)..."; \
	scp -i ~/.ssh/$$KEY_NAME ubuntu@$$MASTER_IP:/home/ubuntu/kubeconfig ./kubeconfig; \
	echo "kubeconfig downloaded successfully!"

# Clean up local files
clean:
	rm -f kubeconfig
	rm -f tfplan
	rm -f .terraform.lock.hcl
	rm -rf .terraform/

# Full cleanup (including destroy)
full-clean: destroy clean

# Show costs
costs:
	@echo "Estimated monthly costs (us-east-2):"
	@echo "- t3.medium (master): ~$$30"
	@echo "- t3.small (worker): ~$$15 each"
	@echo "- EBS storage: ~$$2 per 20GB"
	@echo "- S3: ~$$1 for typical usage"
	@echo "- Total: ~$$50-100/month"
