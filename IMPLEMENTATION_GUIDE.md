# Serverless Bookstore - Implementation Guide

## 📋 Tổng Quan Dự Án

Serverless Bookstore là một ứng dụng quản lý sách được xây dựng hoàn toàn trên AWS Serverless Services:

- **API Backend**: API Gateway + Lambda functions (CRUD operations)
- **Database**: DynamoDB (Books table)
- **Image Processing**: S3 + Lambda (automatic image resizing)
- **Infrastructure as Code**: Terraform với module pattern

**Môi trường hiện tại:** Development (dev)  
**Region:** ap-southeast-1 (Singapore)

---

## 🏗️ Cấu Trúc Dự Án Sau Khi Hoàn Thành

```
ServerlessBookstore/
│
├── environments/                    # Environment-specific configurations
│   └── dev/                        # Development environment
│       ├── backend.tf              # S3 backend configuration
│       ├── provider.tf             # AWS provider settings
│       ├── locals.tf               # Local variables và common tags
│       ├── variables.tf            # Input variables
│       ├── terraform.tfvars        # Variable values for dev
│       ├── main.tf                 # Main infrastructure definition
│       ├── outputs.tf              # Output values (API URL, etc.)
│       └── README.md               # Dev environment documentation
│
├── modules/                         # Reusable Terraform modules
│   ├── api_gateway/                # API Gateway REST API module
│   │   ├── main.tf                 # API Gateway resources
│   │   ├── api_resources.tf        # API routes và methods
│   │   ├── variables.tf            # Module inputs
│   │   └── outputs.tf              # Module outputs
│   │
│   ├── dynamodb/                   # DynamoDB table module
│   │   ├── main.tf                 # ✅ Already complete
│   │   ├── variables.tf            # ✅ Already complete
│   │   └── outputs.tf              # ✅ Already complete
│   │
│   ├── lambda/                     # Lambda function module
│   │   ├── main.tf                 # ⚠️ Needs refactoring
│   │   ├── variables.tf            # ⚠️ Needs updates
│   │   └── outputs.tf              # ✅ Already complete
│   │
│   └── s3/                         # S3 bucket module
│       ├── main.tf                 # ❌ Empty - needs implementation
│       ├── variables.tf            # ❌ Empty - needs implementation
│       └── outputs.tf              # ⚠️ Has outputs but no resources
│
├── functions/                       # Lambda function source code
│   ├── resize-image/               # Image resizing function
│   │   ├── index.js                # ✅ Migrated from /function
│   │   └── package.json            # ✅ Migrated from /function
│   │
│   ├── create-book/                # Create book API function
│   │   ├── index.py                # ⚠️ Migrated from /function_create_book
│   │   └── requirements.txt        # New file
│   │
│   ├── get-book/                   # Get book(s) API function
│   │   ├── index.py                # New function
│   │   └── requirements.txt        # New file
│   │
│   ├── update-book/                # Update book API function
│   │   ├── index.py                # New function
│   │   └── requirements.txt        # New file
│   │
│   └── delete-book/                # Delete book API function
│       ├── index.py                # New function
│       └── requirements.txt        # New file
│
├── shared/                          # Shared configurations
│   └── backend-config.tf           # Backend configuration template
│
├── .gitignore                       # Git ignore rules
├── README.md                        # Project documentation
└── terraform.tfvars.example        # Example variable file

# Files to be DELETED after migration:
# - /function/ (migrated to /functions/resize-image/)
# - /function_create_book/ (migrated to /functions/create-book/)
# - /main.tf (root - empty)
# - /variables.tf (root - moved to environments/dev/)
# - /outputs.tf (root - moved to environments/dev/)
# - /terraform.tfstate* (root - using remote state in S3)
# - /plan.json (no longer needed)
```

---

## 🚀 Implementation Plan - 7 Phases

### **Phase 1: Bootstrap Remote State Backend**

**Mục tiêu:** Tạo infrastructure cho Terraform remote state (S3 + DynamoDB)

**⚠️ Phase này làm THỦ CÔNG hoặc dùng script riêng (không dùng Terraform)**

#### 1.1. Tạo S3 Bucket cho Terraform State

**AWS Console hoặc CLI:**

```bash
# Tạo bucket
aws s3api create-bucket \
  --bucket bookstore-terraform-state \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket bookstore-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket bookstore-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket bookstore-terraform-state \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

#### 1.2. Tạo DynamoDB Table cho State Locking

```bash
aws dynamodb create-table \
  --table-name bookstore-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

#### 1.3. Tạo Shared Backend Configuration Template

**File:** `shared/backend-config.tf`

```hcl
# Backend configuration template
# Copy this to your environment folder and customize

terraform {
  backend "s3" {
    bucket         = "bookstore-terraform-state"
    key            = "environments/{ENVIRONMENT}/terraform.tfstate"  # Replace {ENVIRONMENT}
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "bookstore-terraform-locks"

    # Optional: use specific profile
    # profile = "default"
  }
}
```

**✅ Phase 1 Checklist:**

- [ ] S3 bucket `bookstore-terraform-state` created with versioning and encryption
- [ ] DynamoDB table `bookstore-terraform-locks` created
- [ ] Verified access to both resources with AWS CLI
- [ ] File `shared/backend-config.tf` created

---

### **Phase 2: Refactor Core Modules**

**Mục tiêu:** Hoàn thiện và cải tiến các Terraform modules

---

#### **2.1. Complete S3 Module**

**Files:** `modules/s3/main.tf`, `modules/s3/variables.tf`

##### File: `modules/s3/main.tf`

```hcl
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

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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
```

##### File: `modules/s3/variables.tf`

```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "enable_versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = true
}

variable "enable_cors" {
  description = "Enable CORS configuration"
  type        = bool
  default     = false
}

variable "cors_allowed_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "List of allowed methods for CORS"
  type        = list(string)
  default     = ["GET", "PUT", "POST", "DELETE"]
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "List of headers to expose in CORS"
  type        = list(string)
  default     = []
}

variable "cors_max_age_seconds" {
  description = "Max age for CORS preflight requests"
  type        = number
  default     = 3000
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
```

**✅ S3 Module Checklist:**

- [ ] `modules/s3/main.tf` implemented with bucket, versioning, encryption, public access block
- [ ] `modules/s3/variables.tf` updated with all required variables
- [ ] `modules/s3/outputs.tf` verified (already has correct outputs)

---

#### **2.2. Refactor Lambda Module**

**Files:** `modules/lambda/main.tf`, `modules/lambda/variables.tf`

**Thay đổi chính:**

1. Add environment prefix cho IAM resources
2. Make IAM policies configurable
3. Support multiple runtimes (Node.js, Python)

##### File: `modules/lambda/main.tf` - **CẦN SỬA**

**Tìm và thay thế:**

```hcl
# OLD: Hardcoded IAM role name
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"
  # ...
}

# NEW: Environment-prefixed
resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-${var.function_name}-role"
  # ...
}
```

```hcl
# OLD: Hardcoded S3 policy
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "${var.function_name}-s3-policy"
  description = "IAM policy for Lambda to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.source_bucket_arn}/*"
      },
      # ... hardcoded policies
    ]
  })
}

# NEW: Configurable policies
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.environment}-${var.function_name}-policy"
  description = "IAM policy for Lambda function ${var.function_name}"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = var.iam_policy_statements
  })
}
```

##### File: `modules/lambda/variables.tf` - **THÊM MỚI**

```hcl
# Add these new variables:

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime (nodejs20.x, python3.11, etc.)"
  type        = string
  default     = "nodejs20.x"

  validation {
    condition     = contains(["nodejs20.x", "python3.11", "python3.12"], var.runtime)
    error_message = "Runtime must be one of: nodejs20.x, python3.11, python3.12"
  }
}

variable "iam_policy_statements" {
  description = "List of IAM policy statements for Lambda execution"
  type = list(object({
    Effect   = string
    Action   = list(string)
    Resource = any
  }))
  default = []
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "index.handler"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}
```

**✅ Lambda Module Checklist:**

- [ ] IAM role and policy names include `${var.environment}` prefix
- [ ] Variable `environment` added
- [ ] Variable `runtime` added with validation
- [ ] Variable `iam_policy_statements` added for flexible policies
- [ ] Variables `handler`, `timeout`, `memory_size` added with defaults

---

#### **2.3. Enhance DynamoDB Module**

**File:** `modules/dynamodb/main.tf` - **MINOR UPDATES**

Module này đã khá tốt, chỉ thêm một số enhancements:

```hcl
# Add after the main table resource:

# Point-in-time recovery
resource "aws_dynamodb_table_point_in_time_recovery" "books_pitr" {
  table_name = aws_dynamodb_table.books.name

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }
}
```

##### File: `modules/dynamodb/variables.tf` - **THÊM**

```hcl
variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for the table"
  type        = bool
  default     = true
}

variable "hash_key" {
  description = "Hash key attribute name"
  type        = string
  default     = "id"
}

variable "hash_key_type" {
  description = "Hash key attribute type"
  type        = string
  default     = "S"
}
```

**✅ DynamoDB Module Checklist:**

- [ ] Point-in-time recovery resource added
- [ ] Variables for PITR and hash key configuration added
- [ ] Tags include `ManagedBy = "Terraform"`

---

#### **2.4. Create API Gateway Module**

**NEW MODULE** - Tạo từ đầu

##### File: `modules/api_gateway/main.tf`

```hcl
# REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = var.api_name
  description = "REST API for ${var.api_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(
    var.tags,
    {
      Name        = var.api_name
      Environment = var.environment
    }
  )
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# API Gateway Account (for CloudWatch Logs)
resource "aws_api_gateway_account" "api_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

# IAM Role for API Gateway CloudWatch Logs
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "${var.environment}-${var.api_name}-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

# Attach CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_policy" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  # Force new deployment on any change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.api.body,
      var.deployment_trigger
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_rest_api.api
  ]
}

# Stage
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = var.enable_xray_tracing

  tags = merge(
    var.tags,
    {
      Name = "${var.api_name}-${var.stage_name}"
    }
  )
}

# Method Settings (for throttling and caching)
resource "aws_api_gateway_method_settings" "api_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled      = true
    logging_level        = "INFO"
    data_trace_enabled   = var.enable_data_trace
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }
}
```

##### File: `modules/api_gateway/variables.tf`

```hcl
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "stage_name" {
  description = "Stage name for deployment"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing"
  type        = bool
  default     = false
}

variable "enable_data_trace" {
  description = "Enable data trace logging"
  type        = bool
  default     = false
}

variable "throttling_burst_limit" {
  description = "API throttling burst limit"
  type        = number
  default     = 5000
}

variable "throttling_rate_limit" {
  description = "API throttling rate limit (requests per second)"
  type        = number
  default     = 10000
}

variable "deployment_trigger" {
  description = "Value to trigger redeployment when changed"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

##### File: `modules/api_gateway/outputs.tf`

```hcl
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
```

**✅ API Gateway Module Checklist:**

- [ ] Directory `modules/api_gateway/` created
- [ ] File `main.tf` created with REST API, deployment, stage, logging
- [ ] File `variables.tf` created with all configuration options
- [ ] File `outputs.tf` created with API details

---

### **Phase 3: Setup Environment Structure**

**Mục tiêu:** Tạo cấu trúc folder-based environments

---

#### **3.1. Create Directory Structure**

```bash
# From project root
mkdir -p environments/dev
mkdir -p functions/resize-image
mkdir -p functions/create-book
mkdir -p functions/get-book
mkdir -p functions/update-book
mkdir -p functions/delete-book
mkdir -p shared
```

**Move existing state files (temporary):**

```bash
# Keep state files temporarily for migration
# DON'T delete them yet
```

---

#### **3.2. Create Environment Configuration Files**

##### File: `environments/dev/backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket         = "bookstore-terraform-state"
    key            = "environments/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "bookstore-terraform-locks"
  }
}
```

##### File: `environments/dev/provider.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = local.common_tags
  }
}
```

##### File: `environments/dev/locals.tf`

```hcl
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
```

##### File: `environments/dev/variables.tf`

```hcl
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "bookstore"
}

# Image processing settings
variable "image_width" {
  description = "Width for resized images"
  type        = number
  default     = 200
}

variable "image_height" {
  description = "Height for resized images"
  type        = number
  default     = 280
}

# Lambda settings
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512
}
```

##### File: `environments/dev/terraform.tfvars`

```hcl
# AWS Configuration
aws_region  = "ap-southeast-1"
aws_profile = "default"  # Change to your AWS CLI profile name

# Environment
environment  = "dev"
project_name = "bookstore"

# Image Processing
image_width  = 200
image_height = 280

# Lambda Configuration
lambda_timeout     = 60
lambda_memory_size = 512
```

##### File: `environments/dev/outputs.tf`

```hcl
# API Gateway Outputs
output "api_gateway_url" {
  description = "Base URL for API Gateway"
  value       = module.api_gateway.invoke_url
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}

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
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for books"
  value       = module.dynamodb_books.table_name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.dynamodb_books.table_arn
}

# Lambda Function Outputs
output "lambda_resize_image_arn" {
  description = "ARN of the resize image Lambda function"
  value       = module.lambda_resize_image.function_arn
}

output "lambda_create_book_arn" {
  description = "ARN of the create book Lambda function"
  value       = module.lambda_create_book.function_arn
}

output "lambda_get_book_arn" {
  description = "ARN of the get book Lambda function"
  value       = module.lambda_get_book.function_arn
}

output "lambda_update_book_arn" {
  description = "ARN of the update book Lambda function"
  value       = module.lambda_update_book.function_arn
}

output "lambda_delete_book_arn" {
  description = "ARN of the delete book Lambda function"
  value       = module.lambda_delete_book.function_arn
}
```

##### File: `environments/dev/README.md`

````markdown
# Development Environment

## Overview

This is the development environment for the Serverless Bookstore project.

## Resources Deployed

- **DynamoDB Table:** bookstore-dev-books
- **S3 Buckets:**
  - Source: bookstore-dev-book-images-source
  - Resized: bookstore-dev-book-images-resized
- **Lambda Functions:** 5 functions (resize-image, create/get/update/delete book)
- **API Gateway:** REST API with /books endpoints

## Usage

### Initialize Terraform

```bash
cd environments/dev
terraform init
```
````

### Deploy Infrastructure

```bash
terraform plan
terraform apply
```

### Get API URL

```bash
terraform output api_gateway_url
```

### Destroy Infrastructure

```bash
terraform destroy
```

## Testing

### Test Image Resize

```bash
aws s3 cp test-image.jpg s3://bookstore-dev-book-images-source/
```

### Test Books API

See root README.md for API testing examples.

````

**✅ Phase 3 Checklist:**
- [ ] Directory `environments/dev/` created
- [ ] All configuration files created (backend.tf, provider.tf, locals.tf, variables.tf, terraform.tfvars, outputs.tf)
- [ ] Directory structure for functions created

---

### **Phase 4: Develop Lambda Functions**
**Mục tiêu:** Migrate và tạo mới các Lambda functions

---

#### **4.1. Migrate Resize Image Function**

##### File: `functions/resize-image/index.js`

```javascript
// Copy from /function/index.js
// File đã tốt, chỉ cần move
````

##### File: `functions/resize-image/package.json`

```json
// Copy from /function/package.json
// File đã tốt, chỉ cần move
```

**Command:**

```bash
cp -r function/* functions/resize-image/
```

---

#### **4.2. Migrate và Refactor Create Book Function**

##### File: `functions/create-book/index.py`

```python
import json
import boto3
import os
from datetime import datetime
from uuid import uuid4

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler for creating a new book

    Expected body:
    {
        "title": "Book Title",
        "author": "Author Name",
        "price": 29.99,
        "description": "Book description (optional)",
        "imageUrl": "https://... (optional)"
    }
    """
    try:
        # Parse request body
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event

        # Validate required fields
        if 'title' not in body or 'author' not in body:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing required fields: title and author'
                })
            }

        # Generate book ID
        book_id = str(uuid4())

        # Create book item
        item = {
            'id': book_id,
            'title': body['title'],
            'author': body['author'],
            'price': body.get('price', 0),
            'description': body.get('description', ''),
            'imageUrl': body.get('imageUrl', ''),
            'createdAt': datetime.utcnow().isoformat(),
            'updatedAt': datetime.utcnow().isoformat()
        }

        # Write to DynamoDB
        table.put_item(Item=item)

        return {
            'statusCode': 201,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Book created successfully',
                'book': item
            })
        }

    except Exception as e:
        print(f"Error creating book: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
```

##### File: `functions/create-book/requirements.txt`

```txt
boto3>=1.28.0
```

---

#### **4.3. Create Get Book Function**

##### File: `functions/get-book/index.py`

```python
import json
import boto3
import os
from boto3.dynamodb.conditions import Key

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler for getting book(s)

    Supports two modes:
    1. GET /books -> List all books
    2. GET /books/{id} -> Get single book
    """
    try:
        # Check if this is a single book request
        path_parameters = event.get('pathParameters', {})
        book_id = path_parameters.get('bookId') if path_parameters else None

        if book_id:
            # Get single book
            response = table.get_item(Key={'id': book_id})

            if 'Item' not in response:
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'error': 'Book not found'
                    })
                }

            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'book': response['Item']
                }, default=str)
            }
        else:
            # List all books
            response = table.scan()
            books = response.get('Items', [])

            # Handle pagination if there are more items
            while 'LastEvaluatedKey' in response:
                response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
                books.extend(response.get('Items', []))

            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'books': books,
                    'count': len(books)
                }, default=str)
            }

    except Exception as e:
        print(f"Error getting book(s): {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
```

##### File: `functions/get-book/requirements.txt`

```txt
boto3>=1.28.0
```

---

#### **4.4. Create Update Book Function**

##### File: `functions/update-book/index.py`

```python
import json
import boto3
import os
from datetime import datetime

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler for updating a book

    Expected path parameter: bookId
    Expected body: Fields to update (title, author, price, description, imageUrl)
    """
    try:
        # Get book ID from path parameters
        path_parameters = event.get('pathParameters', {})
        book_id = path_parameters.get('bookId') if path_parameters else None

        if not book_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing book ID'
                })
            }

        # Check if book exists
        existing = table.get_item(Key={'id': book_id})
        if 'Item' not in existing:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Book not found'
                })
            }

        # Parse request body
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event

        # Build update expression
        update_expression = "SET updatedAt = :updatedAt"
        expression_values = {
            ':updatedAt': datetime.utcnow().isoformat()
        }

        # Add fields to update
        updatable_fields = ['title', 'author', 'price', 'description', 'imageUrl']
        for field in updatable_fields:
            if field in body:
                update_expression += f", {field} = :{field}"
                expression_values[f":{field}"] = body[field]

        # Update the item
        response = table.update_item(
            Key={'id': book_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ReturnValues='ALL_NEW'
        )

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': 'Book updated successfully',
                'book': response['Attributes']
            }, default=str)
        }

    except Exception as e:
        print(f"Error updating book: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
```

##### File: `functions/update-book/requirements.txt`

```txt
boto3>=1.28.0
```

---

#### **4.5. Create Delete Book Function**

##### File: `functions/delete-book/index.py`

```python
import json
import boto3
import os

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda handler for deleting a book

    Expected path parameter: bookId
    """
    try:
        # Get book ID from path parameters
        path_parameters = event.get('pathParameters', {})
        book_id = path_parameters.get('bookId') if path_parameters else None

        if not book_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing book ID'
                })
            }

        # Check if book exists
        existing = table.get_item(Key={'id': book_id})
        if 'Item' not in existing:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Book not found'
                })
            }

        # Delete the book
        table.delete_item(Key={'id': book_id})

        return {
            'statusCode': 204,
            'headers': {
                'Access-Control-Allow-Origin': '*'
            },
            'body': ''
        }

    except Exception as e:
        print(f"Error deleting book: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            })
        }
```

##### File: `functions/delete-book/requirements.txt`

```txt
boto3>=1.28.0
```

**✅ Phase 4 Checklist:**

- [ ] Resize image function migrated to `functions/resize-image/`
- [ ] Create book function migrated and refactored in `functions/create-book/`
- [ ] Get book function created in `functions/get-book/`
- [ ] Update book function created in `functions/update-book/`
- [ ] Delete book function created in `functions/delete-book/`
- [ ] All Python functions have requirements.txt

---

### **Phase 5: Wire Everything Together**

**Mục tiêu:** Tạo main infrastructure configuration

---

#### File: `environments/dev/main.tf` (COMPLETE FILE)

```hcl
# ============================================================================
# DynamoDB Table for Books
# ============================================================================

module "dynamodb_books" {
  source = "../../modules/dynamodb"

  dynamodb_table_name           = local.dynamodb_table_name
  environment                   = var.environment
  project_name                  = var.project_name
  enable_point_in_time_recovery = true
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
  source = "../../modules/s3"

  bucket_name       = local.destination_bucket_name
  enable_versioning = true
  tags              = local.common_tags
}

# ============================================================================
# API Gateway
# ============================================================================

module "api_gateway" {
  source = "../../modules/api_gateway"

  api_name     = local.api_name
  environment  = var.environment
  stage_name   = var.environment
  tags         = local.common_tags

  # Trigger redeployment when Lambda functions change
  deployment_trigger = sha1(jsonencode([
    module.lambda_create_book.function_arn,
    module.lambda_get_book.function_arn,
    module.lambda_update_book.function_arn,
    module.lambda_delete_book.function_arn,
  ]))
}

# ============================================================================
# Lambda Functions
# ============================================================================

# 1. Resize Image Function (S3 triggered)
module "lambda_resize_image" {
  source = "../../modules/lambda"

  function_name = local.lambda_resize_image
  environment   = var.environment
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  source_path = "../../functions/resize-image"

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
      Resource = "${module.s3_source.bucket_arn}/*"
    },
    {
      Effect = "Allow"
      Action = [
        "s3:PutObject"
      ]
      Resource = "${module.s3_destination.bucket_arn}/*"
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

  source_bucket_arn = module.s3_source.bucket_arn
}

# 2. Create Book Function
module "lambda_create_book" {
  source = "../../modules/lambda"

  function_name = local.lambda_create_book
  environment   = var.environment
  runtime       = "python3.11"
  handler       = "index.lambda_handler"
  timeout       = 30
  memory_size   = 256

  source_path = "../../functions/create-book"

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
    }
  ]
}

# 3. Get Book Function
module "lambda_get_book" {
  source = "../../modules/lambda"

  function_name = local.lambda_get_book
  environment   = var.environment
  runtime       = "python3.11"
  handler       = "index.lambda_handler"
  timeout       = 30
  memory_size   = 256

  source_path = "../../functions/get-book"

  environment_variables = {
    TABLE_NAME = module.dynamodb_books.table_name
  }

  iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Scan"
      ]
      Resource = module.dynamodb_books.table_arn
    }
  ]
}

# 4. Update Book Function
module "lambda_update_book" {
  source = "../../modules/lambda"

  function_name = local.lambda_update_book
  environment   = var.environment
  runtime       = "python3.11"
  handler       = "index.lambda_handler"
  timeout       = 30
  memory_size   = 256

  source_path = "../../functions/update-book"

  environment_variables = {
    TABLE_NAME = module.dynamodb_books.table_name
  }

  iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem"
      ]
      Resource = module.dynamodb_books.table_arn
    }
  ]
}

# 5. Delete Book Function
module "lambda_delete_book" {
  source = "../../modules/lambda"

  function_name = local.lambda_delete_book
  environment   = var.environment
  runtime       = "python3.11"
  handler       = "index.lambda_handler"
  timeout       = 30
  memory_size   = 256

  source_path = "../../functions/delete-book"

  environment_variables = {
    TABLE_NAME = module.dynamodb_books.table_name
  }

  iam_policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:DeleteItem"
      ]
      Resource = module.dynamodb_books.table_arn
    }
  ]
}

# ============================================================================
# S3 Bucket Notification (Trigger Lambda on Image Upload)
# ============================================================================

resource "aws_s3_bucket_notification" "source_bucket_notification" {
  bucket = module.s3_source.bucket_id

  lambda_function {
    lambda_function_arn = module.lambda_resize_image.function_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [module.lambda_resize_image]
}

# ============================================================================
# API Gateway Resources and Methods
# ============================================================================

# /books resource
resource "aws_api_gateway_resource" "books" {
  rest_api_id = module.api_gateway.api_id
  parent_id   = module.api_gateway.root_resource_id
  path_part   = "books"
}

# /books/{bookId} resource
resource "aws_api_gateway_resource" "book_id" {
  rest_api_id = module.api_gateway.api_id
  parent_id   = aws_api_gateway_resource.books.id
  path_part   = "{bookId}"
}

# ============================================================================
# POST /books - Create Book
# ============================================================================

resource "aws_api_gateway_method" "create_book" {
  rest_api_id   = module.api_gateway.api_id
  resource_id   = aws_api_gateway_resource.books.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_book" {
  rest_api_id             = module.api_gateway.api_id
  resource_id             = aws_api_gateway_resource.books.id
  http_method             = aws_api_gateway_method.create_book.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_create_book.function_invoke_arn
}

resource "aws_lambda_permission" "create_book_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_create_book.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.execution_arn}/*/*"
}

# ============================================================================
# GET /books - List All Books
# ============================================================================

resource "aws_api_gateway_method" "list_books" {
  rest_api_id   = module.api_gateway.api_id
  resource_id   = aws_api_gateway_resource.books.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_books" {
  rest_api_id             = module.api_gateway.api_id
  resource_id             = aws_api_gateway_resource.books.id
  http_method             = aws_api_gateway_method.list_books.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_get_book.function_invoke_arn
}

resource "aws_lambda_permission" "list_books_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_get_book.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.execution_arn}/*/*"
}

# ============================================================================
# GET /books/{bookId} - Get Single Book
# ============================================================================

resource "aws_api_gateway_method" "get_book" {
  rest_api_id   = module.api_gateway.api_id
  resource_id   = aws_api_gateway_resource.book_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bookId" = true
  }
}

resource "aws_api_gateway_integration" "get_book" {
  rest_api_id             = module.api_gateway.api_id
  resource_id             = aws_api_gateway_resource.book_id.id
  http_method             = aws_api_gateway_method.get_book.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_get_book.function_invoke_arn
}

# ============================================================================
# PUT /books/{bookId} - Update Book
# ============================================================================

resource "aws_api_gateway_method" "update_book" {
  rest_api_id   = module.api_gateway.api_id
  resource_id   = aws_api_gateway_resource.book_id.id
  http_method   = "PUT"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bookId" = true
  }
}

resource "aws_api_gateway_integration" "update_book" {
  rest_api_id             = module.api_gateway.api_id
  resource_id             = aws_api_gateway_resource.book_id.id
  http_method             = aws_api_gateway_method.update_book.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_update_book.function_invoke_arn
}

resource "aws_lambda_permission" "update_book_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_update_book.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.execution_arn}/*/*"
}

# ============================================================================
# DELETE /books/{bookId} - Delete Book
# ============================================================================

resource "aws_api_gateway_method" "delete_book" {
  rest_api_id   = module.api_gateway.api_id
  resource_id   = aws_api_gateway_resource.book_id.id
  http_method   = "DELETE"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.bookId" = true
  }
}

resource "aws_api_gateway_integration" "delete_book" {
  rest_api_id             = module.api_gateway.api_id
  resource_id             = aws_api_gateway_resource.book_id.id
  http_method             = aws_api_gateway_method.delete_book.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lambda_delete_book.function_invoke_arn
}

resource "aws_lambda_permission" "delete_book_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_delete_book.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.execution_arn}/*/*"
}

# ============================================================================
# OPTIONS methods for CORS (preflight)
# ============================================================================

# OPTIONS /books
resource "aws_api_gateway_method" "options_books" {
  rest_api_id   = module.api_gateway.api_id
  resource_id   = aws_api_gateway_resource.books.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_books" {
  rest_api_id = module.api_gateway.api_id
  resource_id = aws_api_gateway_resource.books.id
  http_method = aws_api_gateway_method.options_books.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_books" {
  rest_api_id = module.api_gateway.api_id
  resource_id = aws_api_gateway_resource.books.id
  http_method = aws_api_gateway_method.options_books.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_books" {
  rest_api_id = module.api_gateway.api_id
  resource_id = aws_api_gateway_resource.books.id
  http_method = aws_api_gateway_method.options_books.http_method
  status_code = aws_api_gateway_method_response.options_books.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# OPTIONS /books/{bookId}
resource "aws_api_gateway_method" "options_book_id" {
  rest_api_id   = module.api_gateway.api_id
  resource_id   = aws_api_gateway_resource.book_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_book_id" {
  rest_api_id = module.api_gateway.api_id
  resource_id = aws_api_gateway_resource.book_id.id
  http_method = aws_api_gateway_method.options_book_id.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_book_id" {
  rest_api_id = module.api_gateway.api_id
  resource_id = aws_api_gateway_resource.book_id.id
  http_method = aws_api_gateway_method.options_book_id.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_book_id" {
  rest_api_id = module.api_gateway.api_id
  resource_id = aws_api_gateway_resource.book_id.id
  http_method = aws_api_gateway_method.options_book_id.http_method
  status_code = aws_api_gateway_method_response.options_book_id.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}
```

**✅ Phase 5 Checklist:**

- [ ] File `environments/dev/main.tf` created với complete infrastructure
- [ ] All modules called correctly
- [ ] API Gateway resources và methods configured
- [ ] Lambda permissions for API Gateway set
- [ ] S3 notification configured for resize Lambda
- [ ] CORS OPTIONS methods added

---

### **Phase 6: Deploy and Verify**

**Mục tiêu:** Deploy infrastructure và test functionality

---

#### **6.1. Initialize Terraform**

```bash
cd environments/dev

# Initialize Terraform (downloads providers, sets up backend)
terraform init

# If migrating from local state:
# terraform init -migrate-state
```

**Expected Output:**

```
Initializing the backend...
Successfully configured the backend "s3"!
...
Terraform has been successfully initialized!
```

---

#### **6.2. Validate Configuration**

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration syntax
terraform validate

# Review the execution plan
terraform plan -out=tfplan
```

**Review checklist:**

- [ ] No syntax errors
- [ ] Expected number of resources to create
- [ ] Bucket names correct
- [ ] Lambda function names correct
- [ ] No unexpected deletions

---

#### **6.3. Deploy Infrastructure**

```bash
# Apply the plan
terraform apply tfplan

# Or directly apply with approval
terraform apply
```

**This will create:**

- 1 DynamoDB table
- 2 S3 buckets
- 5 Lambda functions
- 1 API Gateway with 5 methods
- IAM roles and policies
- CloudWatch log groups
- S3 bucket notification

**Wait time:** 2-5 minutes

---

#### **6.4. Get Outputs**

```bash
# View all outputs
terraform output

# Get specific output
terraform output api_gateway_url
```

**Save the API Gateway URL** - you'll need it for testing.

---

#### **6.5. Test Image Resize Flow**

```bash
# Set variables
SOURCE_BUCKET=$(terraform output -raw source_bucket_name)

# Upload a test image
aws s3 cp path/to/test-image.jpg s3://$SOURCE_BUCKET/test-image.jpg

# Wait 5-10 seconds for processing

# Check destination bucket
DEST_BUCKET=$(terraform output -raw destination_bucket_name)
aws s3 ls s3://$DEST_BUCKET/

# Should show: resized-test-image.jpg

# Check CloudWatch Logs
aws logs tail /aws/lambda/bookstore-dev-resize-image --follow
```

---

#### **6.6. Test Books API**

```bash
# Get API URL
API_URL=$(terraform output -raw api_gateway_url)

# 1. Create a book
curl -X POST $API_URL/books \
  -H "Content-Type: application/json" \
  -d '{
    "title": "The Terraform Book",
    "author": "John Doe",
    "price": 29.99,
    "description": "A comprehensive guide to Infrastructure as Code"
  }'

# Expected: 201 status, returns book with ID

# 2. List all books
curl $API_URL/books

# Expected: 200 status, array of books

# 3. Get single book (replace {BOOK_ID} with actual ID from create response)
BOOK_ID="your-book-id-here"
curl $API_URL/books/$BOOK_ID

# Expected: 200 status, single book object

# 4. Update book
curl -X PUT $API_URL/books/$BOOK_ID \
  -H "Content-Type: application/json" \
  -d '{
    "title": "The Terraform Book - 2nd Edition",
    "price": 39.99
  }'

# Expected: 200 status, updated book

# 5. Delete book
curl -X DELETE $API_URL/books/$BOOK_ID

# Expected: 204 status, no content

# 6. Verify deletion
curl $API_URL/books/$BOOK_ID

# Expected: 404 status, book not found
```

---

#### **6.7. Verify in AWS Console**

**DynamoDB:**

1. Go to DynamoDB → Tables
2. Look for `bookstore-dev-books`
3. Click "Explore table items"
4. Should see created books

**Lambda:**

1. Go to Lambda → Functions
2. Should see 5 functions with prefix `bookstore-dev-`
3. Check "Monitor" tab for invocations
4. View CloudWatch Logs

**API Gateway:**

1. Go to API Gateway → APIs
2. Look for `bookstore-dev-api`
3. Check "Stages" → dev
4. Invoke URL should match Terraform output

**S3:**

1. Go to S3 → Buckets
2. Should see 2 buckets with prefix `bookstore-dev-`
3. Check source bucket for original images
4. Check destination bucket for resized images

---

#### **6.8. Check Remote State**

```bash
# List state file in S3
aws s3 ls s3://bookstore-terraform-state/environments/dev/

# Should show: terraform.tfstate

# Check lock table
aws dynamodb scan --table-name bookstore-terraform-locks

# Should be empty (no active locks)
```

---

#### **6.9. Verify No Drift**

```bash
# Run plan again
terraform plan

# Expected output: "No changes. Your infrastructure matches the configuration."
```

**✅ Phase 6 Checklist:**

- [ ] `terraform init` successful with S3 backend
- [ ] `terraform validate` passes
- [ ] `terraform apply` creates all resources
- [ ] API Gateway URL accessible
- [ ] Image resize works (S3 → Lambda → S3)
- [ ] All Books API endpoints work (CREATE, READ, UPDATE, DELETE)
- [ ] DynamoDB contains test data
- [ ] CloudWatch Logs show Lambda executions
- [ ] No drift detected with `terraform plan`

---

### **Phase 7: Documentation and Cleanup**

**Mục tiêu:** Finalize documentation và clean up old files

---

#### **7.1. Update Root README**

##### File: `README.md`

```markdown
# Serverless Bookstore

A fully serverless bookstore application built on AWS using Terraform for infrastructure as code.

## Architecture
```

┌─────────────┐ ┌──────────────┐ ┌─────────────┐
│ Client │────────▶│ API Gateway │────────▶│ Lambda │
│ │ │ │ │ Functions │
└─────────────┘ └──────────────┘ └──────┬──────┘
│
▼
┌─────────────┐
│ DynamoDB │
│ (Books) │
└─────────────┘

┌─────────────┐ ┌──────────────┐ ┌─────────────┐
│ S3 │────────▶│ Lambda │────────▶│ S3 │
│ (Source) │ trigger │ (Resize) │ │(Destination)│
└─────────────┘ └──────────────┘ └─────────────┘

```

## Features

- **Books API**: Full CRUD operations (Create, Read, Update, Delete)
- **Image Processing**: Automatic image resizing on S3 upload
- **Serverless**: No servers to manage, pay only for what you use
- **Infrastructure as Code**: Complete infrastructure defined in Terraform
- **Environment Isolation**: Separate dev/staging/prod environments
- **Remote State**: Terraform state stored securely in S3 with locking

## Technology Stack

- **Compute**: AWS Lambda (Node.js 20 & Python 3.11)
- **API**: Amazon API Gateway (REST API)
- **Database**: Amazon DynamoDB
- **Storage**: Amazon S3
- **IaC**: Terraform 1.5+
- **State Management**: S3 + DynamoDB

## Project Structure

See `IMPLEMENTATION_GUIDE.md` for detailed project structure.

```

ServerlessBookstore/
├── environments/dev/ # Dev environment configuration
├── modules/ # Reusable Terraform modules
├── functions/ # Lambda function source code
└── shared/ # Shared configurations

````

## Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5.0
- Node.js 20.x (for local Lambda testing)
- Python 3.11+ (for local Lambda testing)

## Getting Started

### 1. Bootstrap Backend (One-time setup)

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket bookstore-terraform-state \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

aws s3api put-bucket-versioning \
  --bucket bookstore-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name bookstore-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
````

### 2. Deploy Infrastructure

```bash
cd environments/dev

# Initialize Terraform
terraform init

# Review changes
terraform plan

# Deploy
terraform apply
```

### 3. Get API URL

```bash
terraform output api_gateway_url
```

## API Documentation

Base URL: `https://{api-id}.execute-api.ap-southeast-1.amazonaws.com/dev`

### Endpoints

#### Create Book

```bash
POST /books
Content-Type: application/json

{
  "title": "Book Title",
  "author": "Author Name",
  "price": 29.99,
  "description": "Book description",
  "imageUrl": "https://..."
}

Response: 201 Created
{
  "message": "Book created successfully",
  "book": { ... }
}
```

#### List All Books

```bash
GET /books

Response: 200 OK
{
  "books": [ ... ],
  "count": 10
}
```

#### Get Single Book

```bash
GET /books/{bookId}

Response: 200 OK
{
  "book": { ... }
}
```

#### Update Book

```bash
PUT /books/{bookId}
Content-Type: application/json

{
  "title": "Updated Title",
  "price": 39.99
}

Response: 200 OK
{
  "message": "Book updated successfully",
  "book": { ... }
}
```

#### Delete Book

```bash
DELETE /books/{bookId}

Response: 204 No Content
```

## Testing

### Test Books API

```bash
# Set API URL
export API_URL="https://{api-id}.execute-api.ap-southeast-1.amazonaws.com/dev"

# Create a book
curl -X POST $API_URL/books \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Book","author":"Test Author","price":19.99}'

# List books
curl $API_URL/books

# Get specific book
curl $API_URL/books/{book-id}

# Update book
curl -X PUT $API_URL/books/{book-id} \
  -H "Content-Type: application/json" \
  -d '{"title":"Updated Title"}'

# Delete book
curl -X DELETE $API_URL/books/{book-id}
```

### Test Image Resize

```bash
# Upload image to source bucket
aws s3 cp test-image.jpg s3://bookstore-dev-book-images-source/

# Wait a few seconds, then check destination bucket
aws s3 ls s3://bookstore-dev-book-images-resized/
```

## Cost Estimate

With AWS Free Tier, this project should cost **$0-5/month** for light usage:

- DynamoDB: 25GB storage free, 2.5M read/write requests free
- Lambda: 1M requests free, 400,000 GB-seconds free
- API Gateway: 1M requests free (first 12 months)
- S3: 5GB storage free, 20K GET requests free

## Cleanup

To destroy all resources and avoid charges:

```bash
cd environments/dev
terraform destroy
```

⚠️ **Warning**: This will permanently delete all data in DynamoDB and S3 buckets.

## Environment Management

To create additional environments (staging, prod):

```bash
# Copy dev environment
cp -r environments/dev environments/staging

# Update terraform.tfvars with staging-specific values
# Update backend.tf to use different state key
```

## Troubleshooting

### Lambda Function Errors

Check CloudWatch Logs:

```bash
aws logs tail /aws/lambda/bookstore-dev-{function-name} --follow
```

### API Gateway 502 Errors

- Verify Lambda function has API Gateway invoke permission
- Check Lambda function execution role has required permissions

### State Lock Issues

If Terraform reports state is locked:

```bash
# Check for active locks
aws dynamodb scan --table-name bookstore-terraform-locks

# If stuck, manually remove lock (use with caution)
aws dynamodb delete-item \
  --table-name bookstore-terraform-locks \
  --key '{"LockID": {"S": "bookstore-terraform-state/environments/dev/terraform.tfstate"}}'
```

## Contributing

See `IMPLEMENTATION_GUIDE.md` for development workflow and best practices.

## License

MIT License - feel free to use this project for learning and development.

## Author

Built as a learning project for AWS Serverless and Terraform best practices.

## Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [API Gateway REST API Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-rest-api.html)

````

---

#### **7.2. Create .gitignore**

##### File: `.gitignore`

```gitignore
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfvars
!terraform.tfvars.example
.terraform.tfstate.lock.info
terraform.tfplan
tfplan
*.tfplan

# Lambda packages
*.zip
node_modules/
package-lock.json
__pycache__/
*.pyc
*.pyo
*.egg-info/
.venv/
venv/

# OS files
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Logs
*.log
npm-debug.log*

# Backup files
*.backup
*.bak

# Plan output
plan.json
````

---

#### **7.3. Create terraform.tfvars Example**

##### File: `environments/dev/terraform.tfvars.example`

```hcl
# Copy this file to terraform.tfvars and update values

# AWS Configuration
aws_region  = "ap-southeast-1"
aws_profile = "default"  # Your AWS CLI profile

# Environment
environment  = "dev"
project_name = "bookstore"

# Image Processing
image_width  = 200
image_height = 280

# Lambda Configuration
lambda_timeout     = 60
lambda_memory_size = 512
```

---

#### **7.4. Delete Old Files**

```bash
# From project root

# Delete old function directories
rm -rf function/
rm -rf function_create_book/

# Delete old root configuration files (now in environments/dev/)
rm main.tf
rm variables.tf
rm outputs.tf

# Delete old state files (now in S3)
rm terraform.tfstate
rm terraform.tfstate.backup

# Delete old plan
rm plan.json
```

**⚠️ Important**: Only delete these after confirming:

1. Infrastructure is deployed successfully
2. State is migrated to S3
3. All outputs work correctly

---

#### **7.5. Verify Final Structure**

```bash
# Install tree command if needed: npm install -g tree-cli
tree -I 'node_modules|.terraform|*.tfstate*' -L 3
```

**Expected structure:**

```
ServerlessBookstore/
├── environments/
│   └── dev/
│       ├── backend.tf
│       ├── provider.tf
│       ├── locals.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── terraform.tfvars.example
│       ├── main.tf
│       ├── outputs.tf
│       └── README.md
├── modules/
│   ├── api_gateway/
│   ├── dynamodb/
│   ├── lambda/
│   └── s3/
├── functions/
│   ├── resize-image/
│   ├── create-book/
│   ├── get-book/
│   ├── update-book/
│   └── delete-book/
├── shared/
│   └── backend-config.tf
├── .gitignore
├── README.md
└── IMPLEMENTATION_GUIDE.md
```

**✅ Phase 7 Checklist:**

- [ ] Root README.md updated with complete documentation
- [ ] .gitignore created
- [ ] terraform.tfvars.example created
- [ ] Old files deleted (function/, function*create_book/, root *.tf, \_.tfstate)
- [ ] Final directory structure verified
- [ ] All documentation reviewed

---

## 🎉 Implementation Complete!

You now have a production-ready Serverless Bookstore with:

✅ **Infrastructure as Code** - Complete Terraform configuration  
✅ **Best Practices** - Module pattern, remote state, environment isolation  
✅ **Full CRUD API** - All book operations via API Gateway  
✅ **Image Processing** - Automatic S3-triggered resizing  
✅ **Observability** - CloudWatch Logs for all Lambda functions  
✅ **Security** - Least-privilege IAM, encrypted state, no hardcoded secrets  
✅ **Scalability** - Serverless auto-scaling based on demand  
✅ **Documentation** - Complete guides for deployment and usage

---

## 📚 Next Steps (Optional Enhancements)

1. **Add Authentication**
   - Implement AWS Cognito for user authentication
   - Protect API endpoints with JWT validation

2. **Implement CI/CD**
   - GitHub Actions or GitLab CI for automated deployment
   - Separate pipelines for dev/staging/prod

3. **Add Monitoring & Alerts**
   - CloudWatch Alarms for Lambda errors
   - X-Ray tracing for distributed debugging
   - SNS notifications for critical alerts

4. **Enhance API**
   - Add search and filtering
   - Implement pagination for book lists
   - Add API versioning

5. **Cost Optimization**
   - DynamoDB On-Demand to Provisioned (if predictable load)
   - S3 Intelligent-Tiering for storage
   - Lambda Reserved Concurrency (if needed)

6. **Security Hardening**
   - Add WAF rules for API Gateway
   - Implement API throttling per client
   - Enable S3 bucket encryption with KMS
   - VPC for Lambda functions (if needed)

7. **Create Staging & Production Environments**
   - Copy `environments/dev` to `environments/staging` and `environments/prod`
   - Update backend.tf to use different state keys
   - Configure different AWS accounts or profiles

---

## 🆘 Support & Resources

- **Documentation**: See README.md for API usage
- **Terraform Modules**: Check modules/ directory for reusable components
- **AWS Docs**: https://docs.aws.amazon.com/
- **Terraform Registry**: https://registry.terraform.io/

---

**Questions or Issues?**

1. Check CloudWatch Logs: `/aws/lambda/bookstore-dev-*`
2. Verify IAM permissions
3. Run `terraform plan` to check for drift
4. Review AWS service quotas

Good luck with your Serverless Bookstore project! 🚀
