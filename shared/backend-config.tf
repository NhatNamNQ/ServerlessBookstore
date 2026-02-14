# Shared Backend Configuration Template
# This file contains the Terraform backend configuration for S3 + DynamoDB state management
# 
# Usage:
# Copy this configuration to your environment's backend.tf file and customize the key path
# Example: 
#   key = "environments/dev/terraform.tfstate"
#   key = "environments/staging/terraform.tfstate"
#   key = "environments/prod/terraform.tfstate"

terraform {
  backend "s3" {
    # S3 bucket configuration
    bucket  = "116527261062-bookstore-terraform-state"
    key     = "environments/dev/terraform.tfstate" # Update this per environment
    region  = "ap-southeast-1"
    encrypt = true

    # DynamoDB table for state locking
    dynamodb_table = "bookstore-terraform-locks"

    # Optional: Use specific AWS profile
    # profile = "default"
  }
}
