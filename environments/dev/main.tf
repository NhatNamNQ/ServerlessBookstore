# ============================================================================
# DynamoDB Table for Books
# ============================================================================
# COMMENTED OUT FOR TESTING
module "dynamodb_books" {
  source = "../../modules/dynamodb"

  table_name                    = local.dynamodb_table_name
  environment                   = var.environment
  project_name                  = var.project_name
  enable_point_in_time_recovery = true
  tags                          = local.common_tags
}

# ============================================================================
# S3 Buckets
# ============================================================================

# Source bucket for original book images
module "s3_source" {
  source = "../../modules/s3"

  bucket_name       = local.source_bucket_name
  enable_versioning = true
  tags              = local.common_tags
}

# Destination bucket for resized book images
module "s3_destination" {
  source               = "../../modules/s3"
  enable_public_access = true
  bucket_name          = local.destination_bucket_name
  enable_versioning    = true
  tags                 = local.common_tags
}

resource "aws_s3_bucket_policy" "destination_public_policy" {
  bucket = module.s3_destination.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${module.s3_destination.bucket_arn}/*"
      }
    ]
  })
}

# Frontend hosting bucket for static website
module "s3_frontend" {
  source = "../../modules/s3"

  bucket_name                   = local.frontend_bucket_name
  enable_static_website_hosting = true
  enable_public_access          = true
  index_document                = "index.html"
  error_document                = "error.html"
  tags                          = local.common_tags

  bucket_policy_statement = {
    Sid       = "PublicReadGetObject"
    Effect    = "Allow"
    Principal = "*"
    Action    = "s3:GetObject"
    Resource  = "${module.s3_frontend.bucket_arn}/*"
  }
}

# ============================================================================
# API Gateway
# ============================================================================
# COMMENTED OUT FOR TESTING
# module "api_gateway" {
#   source = "../../modules/api_gateway"
#
#   api_name    = local.api_name
#   environment = var.environment
#   stage_name  = var.environment
#   tags        = local.common_tags
#
#   deployment_trigger = sha1(jsonencode([
#     module.lambda_create_book.function_arn,
#     module.lambda_get_book.function_arn,
#     module.lambda_update_book.function_arn,
#     module.lambda_delete_book.function_arn,
#   ]))
# }

# ============================================================================
# Lambda Functions
# ============================================================================

# 1. Resize Image Function (S3 triggered)
module "lambda_resize_image" {
  source = "../../modules/lambda"

  function_name = "resize-image"
  environment   = var.environment
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size
  source_path   = "../../function"
  tags          = local.common_tags

  environment_variables = {
    REGION     = var.aws_region
    WIDTH      = var.image_width
    HEIGHT     = var.image_height
    DES_BUCKET = module.s3_destination.bucket_name
  }

  iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:DeleteObject"
      ]
      Resource = ["${module.s3_source.bucket_arn}/*"]
    },
    {
      Effect = "Allow"
      Action = [
        "s3:PutObject"
      ]
      Resource = ["${module.s3_destination.bucket_arn}/*"]
    },
    {
      Effect = "Allow"
      Action = [
        "s3:ListBucket"
      ]
      Resource = [
        module.s3_source.bucket_arn,
        module.s3_destination.bucket_arn
      ]
    }
  ]
}

# 2. Create Book Function
# COMMENTED OUT FOR TESTING
module "lambda_create_book" {
  source = "../../modules/lambda"

  function_name = "create-book"
  environment   = var.environment // dev
  runtime       = "python3.11"
  handler       = "index.lambda_handler"
  timeout       = 30
  memory_size   = 256
  source_path   = "../../functions/create-book"
  tags          = local.common_tags

  environment_variables = {
    TABLE_NAME = module.dynamodb_books.table_name
  }

  iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem"
      ]
      Resource = module.dynamodb_books.table_arn
    },
    {
      Effect = "Allow"
      Action = [
        "s3:PutObject"
      ]
      Resource = "${module.s3_source.bucket_arn}/*"
    }
  ]
}

# 3. Get Book Function
# COMMENTED OUT FOR TESTING
# module "lambda_get_book" {
#   source = "../../modules/lambda"
#
#   function_name = "get-book"
#   environment   = var.environment
#   runtime       = "python3.11"
#   handler       = "index.lambda_handler"
#   timeout       = 30
#   memory_size   = 256
#   source_path   = "../../functions/get-book"
#   tags          = local.common_tags
#
#   environment_variables = {
#     TABLE_NAME = module.dynamodb_books.table_name
#   }
#
#   iam_policy_statements = [
#     {
#       Effect = "Allow"
#       Action = [
#         "dynamodb:GetItem",
#         "dynamodb:Scan"
#       ]
#       Resource = module.dynamodb_books.table_arn
#     }
#   ]
# }

# 4. Update Book Function
# COMMENTED OUT FOR TESTING
# module "lambda_update_book" {
#   source = "../../modules/lambda"
#
#   function_name = "update-book"
#   environment   = var.environment
#   runtime       = "python3.11"
#   handler       = "index.lambda_handler"
#   timeout       = 30
#   memory_size   = 256
#   source_path   = "../../functions/update-book"
#   tags          = local.common_tags
#
#   environment_variables = {
#     TABLE_NAME = module.dynamodb_books.table_name
#   }
#
#   iam_policy_statements = [
#     {
#       Effect = "Allow"
#       Action = [
#         "dynamodb:GetItem",
#         "dynamodb:UpdateItem"
#       ]
#       Resource = module.dynamodb_books.table_arn
#     }
#   ]
# }

# 5. Delete Book Function
# COMMENTED OUT FOR TESTING
# module "lambda_delete_book" {
#   source = "../../modules/lambda"
#
#   function_name = "delete-book"
#   environment   = var.environment
#   runtime       = "python3.11"
#   handler       = "index.lambda_handler"
#   timeout       = 30
#   memory_size   = 256
#   source_path   = "../../functions/delete-book"
#   tags          = local.common_tags
#
#   environment_variables = {
#     TABLE_NAME = module.dynamodb_books.table_name
#   }
#
#   iam_policy_statements = [
#     {
#       Effect = "Allow"
#       Action = [
#         "dynamodb:GetItem",
#         "dynamodb:DeleteItem"
#       ]
#       Resource = module.dynamodb_books.table_arn
#     }
#   ]
# }

# ============================================================================
# S3 Bucket Notification (Trigger Lambda on Image Upload)
# ============================================================================

resource "aws_s3_bucket_notification" "source_bucket_notification" {
  bucket = module.s3_source.bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_resize_image.function_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
# Permission for S3 to invoke resize Lambda
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_resize_image.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.s3_source.bucket_arn
}

# ============================================================================
# API Gateway Resources and Methods
# ============================================================================
# COMMENTED OUT FOR TESTING
#
# # /books resource
# resource "aws_api_gateway_resource" "books" {
#   rest_api_id = module.api_gateway.api_id
#   parent_id   = module.api_gateway.root_resource_id
#   path_part   = "books"
# }
#
# # /books/{bookId} resource
# resource "aws_api_gateway_resource" "book_id" {
#   rest_api_id = module.api_gateway.api_id
#   parent_id   = aws_api_gateway_resource.books.id
#   path_part   = "{bookId}"
# }
#
# # ============================================================================
# # POST /books - Create Book
# # ============================================================================
#
# resource "aws_api_gateway_method" "create_book" {
#   rest_api_id   = module.api_gateway.api_id
#   resource_id   = aws_api_gateway_resource.books.id
#   http_method   = "POST"
#   authorization = "NONE"
# }
#
# resource "aws_api_gateway_integration" "create_book" {
#   rest_api_id             = module.api_gateway.api_id
#   resource_id             = aws_api_gateway_resource.books.id
#   http_method             = aws_api_gateway_method.create_book.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = module.lambda_create_book.function_invoke_arn
# }
#
# resource "aws_lambda_permission" "create_book_api_gateway" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = module.lambda_create_book.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${module.api_gateway.execution_arn}/*/*"
# }
#
# # ============================================================================
# # GET /books - List All Books
# # ============================================================================
#
# resource "aws_api_gateway_method" "list_books" {
#   rest_api_id   = module.api_gateway.api_id
#   resource_id   = aws_api_gateway_resource.books.id
#   http_method   = "GET"
#   authorization = "NONE"
# }
#
# resource "aws_api_gateway_integration" "list_books" {
#   rest_api_id             = module.api_gateway.api_id
#   resource_id             = aws_api_gateway_resource.books.id
#   http_method             = aws_api_gateway_method.list_books.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = module.lambda_get_book.function_invoke_arn
# }
#
# resource "aws_lambda_permission" "list_books_api_gateway" {
#   statement_id  = "AllowAPIGatewayInvokeList"
#   action        = "lambda:InvokeFunction"
#   function_name = module.lambda_get_book.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${module.api_gateway.execution_arn}/*/*"
# }
#
# # ============================================================================
# # GET /books/{bookId} - Get Single Book
# # ============================================================================
#
# resource "aws_api_gateway_method" "get_book" {
#   rest_api_id   = module.api_gateway.api_id
#   resource_id   = aws_api_gateway_resource.book_id.id
#   http_method   = "GET"
#   authorization = "NONE"
#
#   request_parameters = {
#     "method.request.path.bookId" = true
#   }
# }
#
# resource "aws_api_gateway_integration" "get_book" {
#   rest_api_id             = module.api_gateway.api_id
#   resource_id             = aws_api_gateway_resource.book_id.id
#   http_method             = aws_api_gateway_method.get_book.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = module.lambda_get_book.function_invoke_arn
# }
#
# # ============================================================================
# # PUT /books/{bookId} - Update Book
# # ============================================================================
#
# resource "aws_api_gateway_method" "update_book" {
#   rest_api_id   = module.api_gateway.api_id
#   resource_id   = aws_api_gateway_resource.book_id.id
#   http_method   = "PUT"
#   authorization = "NONE"
#
#   request_parameters = {
#     "method.request.path.bookId" = true
#   }
# }
#
# resource "aws_api_gateway_integration" "update_book" {
#   rest_api_id             = module.api_gateway.api_id
#   resource_id             = aws_api_gateway_resource.book_id.id
#   http_method             = aws_api_gateway_method.update_book.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = module.lambda_update_book.function_invoke_arn
# }
#
# resource "aws_lambda_permission" "update_book_api_gateway" {
#   statement_id  = "AllowAPIGatewayInvokeUpdate"
#   action        = "lambda:InvokeFunction"
#   function_name = module.lambda_update_book.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${module.api_gateway.execution_arn}/*/*"
# }
#
# # ============================================================================
# # DELETE /books/{bookId} - Delete Book
# # ============================================================================
#
# resource "aws_api_gateway_method" "delete_book" {
#   rest_api_id   = module.api_gateway.api_id
#   resource_id   = aws_api_gateway_resource.book_id.id
#   http_method   = "DELETE"
#   authorization = "NONE"
#
#   request_parameters = {
#     "method.request.path.bookId" = true
#   }
# }
#
# resource "aws_api_gateway_integration" "delete_book" {
#   rest_api_id             = module.api_gateway.api_id
#   resource_id             = aws_api_gateway_resource.book_id.id
#   http_method             = aws_api_gateway_method.delete_book.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = module.lambda_delete_book.function_invoke_arn
# }
#
# resource "aws_lambda_permission" "delete_book_api_gateway" {
#   statement_id  = "AllowAPIGatewayInvokeDelete"
#   action        = "lambda:InvokeFunction"
#   function_name = module.lambda_delete_book.function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${module.api_gateway.execution_arn}/*/*"
# }
#
# # ============================================================================
# # OPTIONS methods for CORS (preflight)
# # ============================================================================
#
# # OPTIONS /books
# resource "aws_api_gateway_method" "options_books" {
#   rest_api_id   = module.api_gateway.api_id
#   resource_id   = aws_api_gateway_resource.books.id
#   http_method   = "OPTIONS"
#   authorization = "NONE"
# }
#
# resource "aws_api_gateway_integration" "options_books" {
#   rest_api_id = module.api_gateway.api_id
#   resource_id = aws_api_gateway_resource.books.id
#   http_method = aws_api_gateway_method.options_books.http_method
#   type        = "MOCK"
#
#   request_templates = {
#     "application/json" = "{\"statusCode\": 200}"
#   }
# }
#
# resource "aws_api_gateway_method_response" "options_books_200" {
#   rest_api_id = module.api_gateway.api_id
#   resource_id = aws_api_gateway_resource.books.id
#   http_method = aws_api_gateway_method.options_books.http_method
#   status_code = "200"
#
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = true
#     "method.response.header.Access-Control-Allow-Methods" = true
#     "method.response.header.Access-Control-Allow-Origin"  = true
#   }
# }
#
# resource "aws_api_gateway_integration_response" "options_books" {
#   rest_api_id = module.api_gateway.api_id
#   resource_id = aws_api_gateway_resource.books.id
#   http_method = aws_api_gateway_method.options_books.http_method
#   status_code = aws_api_gateway_method_response.options_books_200.status_code
#
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
#     "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
#     "method.response.header.Access-Control-Allow-Origin"  = "'*'"
#   }
# }
#
# # OPTIONS /books/{bookId}
# resource "aws_api_gateway_method" "options_book_id" {
#   rest_api_id   = module.api_gateway.api_id
#   resource_id   = aws_api_gateway_resource.book_id.id
#   http_method   = "OPTIONS"
#   authorization = "NONE"
# }
#
# resource "aws_api_gateway_integration" "options_book_id" {
#   rest_api_id = module.api_gateway.api_id
#   resource_id = aws_api_gateway_resource.book_id.id
#   http_method = aws_api_gateway_method.options_book_id.http_method
#   type        = "MOCK"
#
#   request_templates = {
#     "application/json" = "{\"statusCode\": 200}"
#   }
# }
#
# resource "aws_api_gateway_method_response" "options_book_id_200" {
#   rest_api_id = module.api_gateway.api_id
#   resource_id = aws_api_gateway_resource.book_id.id
#   http_method = aws_api_gateway_method.options_book_id.http_method
#   status_code = "200"
#
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = true
#     "method.response.header.Access-Control-Allow-Methods" = true
#     "method.response.header.Access-Control-Allow-Origin"  = true
#   }
# }
#
# resource "aws_api_gateway_integration_response" "options_book_id" {
#   rest_api_id = module.api_gateway.api_id
#   resource_id = aws_api_gateway_resource.book_id.id
#   http_method = aws_api_gateway_method.options_book_id.http_method
#   status_code = aws_api_gateway_method_response.options_book_id_200.status_code
#
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
#     "method.response.header.Access-Control-Allow-Methods" = "'GET,PUT,DELETE,OPTIONS'"
#     "method.response.header.Access-Control-Allow-Origin"  = "'*'"
#   }
# }
