output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "k8s_master_public_ip" {
  description = "Public IP address of the Kubernetes master node"
  value       = aws_instance.k8s_master.public_ip
}

output "k8s_master_private_ip" {
  description = "Private IP address of the Kubernetes master node"
  value       = aws_instance.k8s_master.private_ip
}

output "k8s_worker_public_ips" {
  description = "Public IP addresses of the Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].public_ip
}

output "k8s_worker_private_ips" {
  description = "Private IP addresses of the Kubernetes worker nodes"
  value       = aws_instance.k8s_workers[*].private_ip
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for AI agent files"
  value       = aws_s3_bucket.ai_agent_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for AI agent files"
  value       = aws_s3_bucket.ai_agent_bucket.arn
}

output "kubeconfig_command" {
  description = "Command to download kubeconfig from master node"
  value       = "scp -i ~/.ssh/${var.key_pair_name != "" ? var.key_pair_name : "${local.name_prefix}-k8s-key"} ubuntu@${aws_instance.k8s_master.public_ip}:/home/ubuntu/kubeconfig ./kubeconfig"
}

output "kubectl_setup_command" {
  description = "Command to set up kubectl with the cluster"
  value       = "export KUBECONFIG=./kubeconfig && kubectl get nodes"
}

output "helm_setup_command" {
  description = "Command to set up Helm with the cluster"
  value       = "export KUBECONFIG=./kubeconfig && helm list --all-namespaces"
}

output "ai_agent_service_url" {
  description = "URL to access the AI agent service"
  value       = "http://${aws_instance.k8s_master.public_ip}:30000"
}

output "ssh_connect_master" {
  description = "SSH command to connect to master node"
  value       = "ssh -i ~/.ssh/${var.key_pair_name != "" ? var.key_pair_name : "${local.name_prefix}-k8s-key"} ubuntu@${aws_instance.k8s_master.public_ip}"
}

output "ssh_connect_workers" {
  description = "SSH commands to connect to worker nodes"
  value       = [for i, worker in aws_instance.k8s_workers : "ssh -i ~/.ssh/${var.key_pair_name != "" ? var.key_pair_name : "${local.name_prefix}-k8s-key"} ubuntu@${worker.public_ip}"]
}

output "ssh_key_name" {
  description = "Name of the SSH key pair used for EC2 instances"
  value       = var.key_pair_name != "" ? var.key_pair_name : "${local.name_prefix}-k8s-key"
}
