resource "aws_dynamodb_table" "books" {
  name             = var.table_name
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = var.hash_key
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = var.hash_key
    type = var.hash_key_type
  }

  tags = merge(
    var.tags,
    {
      Name        = var.table_name
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  )
}

# Point-in-time recovery
# resource "aws_dynamodb_table_point_in_time_recovery" "recovery" {
#   table_name = aws_dynamodb_table.books.name

#   point_in_time_recovery {
#     enabled = var.enable_point_in_time_recovery
#   }
# }

# Table TTL (optional)
# resource "aws_dynamodb_table_ttl" "ttl" {
#   count          = var.enable_ttl ? 1 : 0
#   name           = aws_dynamodb_table.books.name
#   attribute_name = var.ttl_attribute_name
#   enabled        = true
# }

