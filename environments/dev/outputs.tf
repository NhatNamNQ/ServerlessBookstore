# API Gateway Outputs
# output "api_gateway_url" {
#   description = "Base URL for API Gateway"
#   value       = module.api_gateway.invoke_url
# }

# output "api_gateway_id" {
#   description = "API Gateway REST API ID"
#   value       = module.api_gateway.api_id
# }

# S3 Bucket Outputs
output "source_bucket_name" {
  description = "Name of the source S3 bucket for book images"
  value       = module.s3_source.bucket_name
}

output "destination_bucket_name" {
  description = "Name of the destination S3 bucket for resized images"
  value       = module.s3_destination.bucket_name
}

# DynamoDB Outputs
# output "dynamodb_table_name" {
#   description = "Name of the DynamoDB table for books"
#   value       = module.dynamodb_books.table_name
# }

# output "dynamodb_table_arn" {
#   description = "ARN of the DynamoDB table"
#   value       = module.dynamodb_books.table_arn
# }

# Lambda Function Outputs
output "lambda_resize_image_arn" {
  description = "ARN of the resize image Lambda function"
  value       = module.lambda_resize_image.function_arn
}

# output "lambda_create_book_arn" {
#   description = "ARN of the create book Lambda function"
#   value       = module.lambda_create_book.function_arn
# }

# output "lambda_get_book_arn" {
#   description = "ARN of the get book Lambda function"
#   value       = module.lambda_get_book.function_arn
# }

# output "lambda_update_book_arn" {
#   description = "ARN of the update book Lambda function"
#   value       = module.lambda_update_book.function_arn
# }

# output "lambda_delete_book_arn" {
#   description = "ARN of the delete book Lambda function"
#   value       = module.lambda_delete_book.function_arn
# }
