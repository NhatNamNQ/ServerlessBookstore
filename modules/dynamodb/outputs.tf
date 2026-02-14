output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.books.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.books.arn
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.books.id
}

output "stream_arn" {
  description = "ARN of the DynamoDB streams"
  value       = aws_dynamodb_table.books.stream_arn
}

