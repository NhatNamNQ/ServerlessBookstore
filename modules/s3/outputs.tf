output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.bucket.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.bucket.bucket
}

output "website_endpoint" {
  description = "The website endpoint of the S3 bucket (if static website hosting is enabled)"
  value       = try(aws_s3_bucket_website_configuration.bucket_website[0].website_endpoint, null)
}

