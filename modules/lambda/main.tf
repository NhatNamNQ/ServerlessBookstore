# Archive Lambda source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_path
  output_path = "${path.module}/${var.environment}-${var.function_name}.zip"
}

# IAM Role for Lambda Execution
resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda (Configurable)
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.environment}-${var.function_name}-policy"
  description = "IAM policy for Lambda function ${var.function_name}"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.iam_policy_statements
  })

  tags = var.tags
}

# Attach IAM Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Attach AWS Managed Policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.environment}-${var.function_name}"
  role             = aws_iam_role.lambda_role.arn
  handler          = var.handler
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = var.environment_variables
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment,
    aws_iam_role_policy_attachment.lambda_logs
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.function_name}"
    }
  )
}
