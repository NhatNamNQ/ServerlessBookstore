# S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name = var.bucket_name
    }
  )
}

# Versioning configuration
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "bucket_pab" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = !var.enable_public_access
  block_public_policy     = !var.enable_public_access
  ignore_public_acls      = !var.enable_public_access
  restrict_public_buckets = !var.enable_public_access
}

# CORS configuration (optional)
resource "aws_s3_bucket_cors_configuration" "bucket_cors" {
  count  = var.enable_cors ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.cors_allowed_origins
    expose_headers  = var.cors_expose_headers
    max_age_seconds = var.cors_max_age_seconds
  }
}

# Static website hosting configuration (optional)
resource "aws_s3_bucket_website_configuration" "bucket_website" {
  count  = var.enable_static_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

# Custom bucket policy (optional)
resource "aws_s3_bucket_policy" "bucket_policy" {
  count  = var.bucket_policy_statement != null ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  # Must depend on bucket_pab to ensure block public access is disabled first
  depends_on = [aws_s3_bucket_public_access_block.bucket_pab]

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [var.bucket_policy_statement]
  })
}

