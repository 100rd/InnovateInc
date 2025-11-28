# ============================================================================
# S3 Bucket for Terraform State - PRODUCTION PROTECTED
# ============================================================================

resource "aws_s3_bucket" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = local.state_bucket_name

  # PROTECTION 1: Prevent Terraform from destroying bucket with objects
  force_destroy = false

  # PROTECTION 2: Terraform will error if trying to destroy this resource
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Module         = "S3/Terraform-State"
      CriticalData   = "true"
      BackupRequired = "true"
    }
  )
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# PROTECTION 3: Bucket Policy - Enforce security best practices
resource "aws_s3_bucket_policy" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state[0].arn,
          "${aws_s3_bucket.terraform_state[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "RequireEncryption"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.terraform_state[0].arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      }
    ]
  })
}

# PROTECTION 4: Lifecycle Policy - Retain old versions for recovery
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count = var.create_state_bucket ? 1 : 0

  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    id     = "retain-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    # Keep old versions for 1 year before deletion
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }

  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
