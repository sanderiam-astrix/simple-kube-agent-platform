# Data source for latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate SSH key pair if not provided
resource "tls_private_key" "k8s_key" {
  count     = var.key_pair_name == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "k8s_key" {
  count      = var.key_pair_name == "" ? 1 : 0
  key_name   = "${local.name_prefix}-k8s-key"
  public_key = tls_private_key.k8s_key[0].public_key_openssh

  tags = local.common_tags
}

# Save the private key to local filesystem
resource "local_file" "k8s_private_key" {
  count    = var.key_pair_name == "" ? 1 : 0
  filename = "${path.module}/${local.name_prefix}-k8s-key.pem"
  content  = tls_private_key.k8s_key[0].private_key_pem
  file_permission = "0600"

  depends_on = [tls_private_key.k8s_key]
}

# Kubernetes Master Node
resource "aws_instance" "k8s_master" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_master
  key_name               = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.k8s_key[0].key_name
  vpc_security_group_ids = [aws_security_group.k8s_master.id]
  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = aws_iam_instance_profile.k8s_master.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/master-init.sh", {
    kubernetes_version = var.kubernetes_version
    enable_sidecar     = var.enable_sidecar
    s3_bucket_name     = aws_s3_bucket.ai_agent_bucket.bucket
    aws_region         = var.aws_region
  }))

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.key_pair_name != "" ? file("~/.ssh/${var.key_pair_name}.pem") : tls_private_key.k8s_key[0].private_key_pem
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/ai-agent-deployment.yaml"
    destination = "/tmp/ai-agent-deployment.yaml"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-k8s-master"
    Type = "Master"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Kubernetes Worker Nodes
resource "aws_instance" "k8s_workers" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type_worker
  key_name               = var.key_pair_name != "" ? var.key_pair_name : aws_key_pair.k8s_key[0].key_name
  vpc_security_group_ids = [aws_security_group.k8s_worker.id]
  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = aws_iam_instance_profile.k8s_worker.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  user_data = base64encode(templatefile("${path.module}/scripts/worker-init.sh", {
    kubernetes_version = var.kubernetes_version
    master_ip         = aws_instance.k8s_master.private_ip
    s3_bucket_name    = aws_s3_bucket.ai_agent_bucket.bucket
    aws_region        = var.aws_region
  }))

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.key_pair_name != "" ? file("~/.ssh/${var.key_pair_name}.pem") : tls_private_key.k8s_key[0].private_key_pem
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install-claude-code.sh"
    destination = "/tmp/install-claude-code.sh"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-k8s-worker-${count.index + 1}"
    Type = "Worker"
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_instance.k8s_master]
}
