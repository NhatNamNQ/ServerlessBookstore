variable "function_name" {
  description = "Name of the Lambda function (without environment prefix)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "source_path" {
  description = "Path to Lambda function source code directory"
  type        = string
}

variable "runtime" {
  description = "Lambda function runtime"
  type        = string
  default     = "nodejs20.x"

  validation {
    condition     = contains(["nodejs20.x", "nodejs18.x", "python3.11", "python3.12"], var.runtime)
    error_message = "Runtime must be one of: nodejs20.x, nodejs18.x, python3.11, python3.12"
  }
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

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds"
  }
}

variable "memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 512

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB"
  }
}

variable "environment_variables" {
  description = "Environment variables for Lambda function"
  type        = map(string)
  default     = {}
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

variable "tags" {
  description = "Tags to apply to Lambda resources"
  type        = map(string)
  default     = {}
}

