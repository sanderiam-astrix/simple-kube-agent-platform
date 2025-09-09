# S3 Bucket for AI Agent file storage
resource "aws_s3_bucket" "ai_agent_bucket" {
  bucket = "${local.name_prefix}-ai-agent-files-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ai-agent-files"
  })
}

# Random ID for bucket suffix to ensure uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "ai_agent_bucket" {
  bucket = aws_s3_bucket.ai_agent_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "ai_agent_bucket" {
  bucket = aws_s3_bucket.ai_agent_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "ai_agent_bucket" {
  bucket = aws_s3_bucket.ai_agent_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "ai_agent_bucket" {
  bucket = aws_s3_bucket.ai_agent_bucket.id

  rule {
    id     = "delete_old_versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
