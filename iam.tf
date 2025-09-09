# IAM Role for Kubernetes Master
resource "aws_iam_role" "k8s_master" {
  name = "${local.name_prefix}-k8s-master-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Role for Kubernetes Workers
resource "aws_iam_role" "k8s_worker" {
  name = "${local.name_prefix}-k8s-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for S3 access
resource "aws_iam_policy" "s3_access" {
  name        = "${local.name_prefix}-s3-access-policy"
  description = "Policy for S3 access from Kubernetes pods"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ai_agent_bucket.arn,
          "${aws_s3_bucket.ai_agent_bucket.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Attach S3 policy to worker role
resource "aws_iam_role_policy_attachment" "k8s_worker_s3" {
  role       = aws_iam_role.k8s_worker.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# Attach basic EC2 policies
resource "aws_iam_role_policy_attachment" "k8s_master_ec2" {
  role       = aws_iam_role.k8s_master.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "k8s_worker_ec2" {
  role       = aws_iam_role.k8s_worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Instance profiles
resource "aws_iam_instance_profile" "k8s_master" {
  name = "${local.name_prefix}-k8s-master-profile"
  role = aws_iam_role.k8s_master.name

  tags = local.common_tags
}

resource "aws_iam_instance_profile" "k8s_worker" {
  name = "${local.name_prefix}-k8s-worker-profile"
  role = aws_iam_role.k8s_worker.name

  tags = local.common_tags
}
