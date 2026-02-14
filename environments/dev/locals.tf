locals {
  # Common tags applied to all resources
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = "Development"
  }

  # Naming prefixes
  name_prefix = "${var.project_name}-${var.environment}"

  # Bucket names
  source_bucket_name      = "${local.name_prefix}-book-images-source"
  destination_bucket_name = "${local.name_prefix}-book-images-resized"
  frontend_bucket_name    = "${local.name_prefix}-frontend"

  # DynamoDB table name
  dynamodb_table_name = "${local.name_prefix}-books"

  # API Gateway name
  api_name = "${local.name_prefix}-api"

  # Lambda function names
  lambda_resize_image = "${local.name_prefix}-resize-image"
  lambda_create_book  = "${local.name_prefix}-create-book"
  lambda_get_book     = "${local.name_prefix}-get-book"
  lambda_update_book  = "${local.name_prefix}-update-book"
  lambda_delete_book  = "${local.name_prefix}-delete-book"
}
