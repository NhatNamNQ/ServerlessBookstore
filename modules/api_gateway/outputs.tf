output "api_id" {
  description = "ID of the REST API"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_arn" {
  description = "ARN of the REST API"
  value       = aws_api_gateway_rest_api.api.arn
}

output "root_resource_id" {
  description = "Root resource ID of the REST API"
  value       = aws_api_gateway_rest_api.api.root_resource_id
}

output "execution_arn" {
  description = "Execution ARN of the REST API"
  value       = aws_api_gateway_rest_api.api.execution_arn
}

output "invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  value       = aws_api_gateway_stage.api_stage.invoke_url
}

output "stage_name" {
  description = "Name of the deployed stage"
  value       = aws_api_gateway_stage.api_stage.stage_name
}

output "deployment_id" {
  description = "ID of the deployment"
  value       = aws_api_gateway_deployment.api_deployment.id
}
